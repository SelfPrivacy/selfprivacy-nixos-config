import base64
import hashlib
import html
import imaplib
import re
import secrets
import smtplib
import ssl
import subprocess
import time
from email.message import EmailMessage
from urllib.parse import parse_qs, urlparse, urlunparse

import pyotp
import requests

API_URL = "https://api.example.test"
KANIDM_URL = "https://auth.example.test"
MAILSERVER = "example.test"

USERNAME = "deer"
KANIDM_PASSWORD = secrets.token_urlsafe(24)
SUBJECT = "Acorns delivery"
CA_FILE = "/etc/ssl/certs/ca-certificates.crt"

API_TOKEN = subprocess.check_output(["sp-print-api-token"], text=True).strip()


def http_session():
    session = requests.Session()
    session.verify = CA_FILE
    return session


HTTP_SESSION = http_session()


def checked_request(response, description):
    try:
        response.raise_for_status()
    except requests.HTTPError as error:
        raise AssertionError(
            f"{description} failed: {response.status_code} {response.text}"
        ) from error
    return response


def graphql(query, variables):
    response = checked_request(
        HTTP_SESSION.post(
            f"{API_URL}/graphql",
            headers={"Authorization": f"Bearer {API_TOKEN}"},
            json={"query": query, "variables": variables},
            timeout=30,
        ),
        "GraphQL request",
    )
    result = response.json()
    assert "errors" not in result, result
    return result["data"]


def totp_code(secret):
    base32_secret = base64.b32encode(bytes(secret["secret"])).decode()
    totp = pyotp.TOTP(
        base32_secret,
        digits=secret["digits"],
        interval=secret["step"],
        digest=getattr(hashlib, secret["algo"].lower()),
    )
    return int(totp.now())


def create_user_and_set_identity_password():
    result = graphql(
        """
        mutation CreateUser($username: String!) {
          users {
            createUser(user: {username: $username}) {
              success
              code
              message
            }
          }
        }
        """,
        {"username": USERNAME},
    )["users"]["createUser"]
    assert result["success"], result

    result = graphql(
        """
        mutation GeneratePasswordResetLink($username: String!) {
          users {
            generatePasswordResetLink(username: $username) {
              success
              code
              message
              passwordResetLink
            }
          }
        }
        """,
        {"username": USERNAME},
    )["users"]["generatePasswordResetLink"]
    assert result["success"], result

    intent_token = parse_qs(urlparse(result["passwordResetLink"]).query)["token"][0]
    response = checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/v1/credential/_exchange_intent",
            json=intent_token,
            timeout=30,
        ),
        "credential intent exchange",
    )
    credential_session, _status = response.json()

    checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/v1/credential/_update",
            json=[{"password": KANIDM_PASSWORD}, credential_session],
            timeout=30,
        ),
        "identity password update",
    )

    response = checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/v1/credential/_update",
            json=["totpgenerate", credential_session],
            timeout=30,
        ),
        "TOTP generation",
    )
    totp_secret = response.json()["mfaregstate"]["TotpCheck"]

    response = checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/v1/credential/_update",
            json=[
                {"totpverify": [totp_code(totp_secret), "Test"]},
                credential_session,
            ],
            timeout=30,
        ),
        "TOTP verification",
    )
    assert response.json()["can_commit"], response.json()

    checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/v1/credential/_commit",
            json=credential_session,
            timeout=30,
        ),
        "identity password commit",
    )
    return totp_secret


def kanidm_user_auth_token(totp_secret):
    # kanidm uses cookies to store auth process
    session = http_session()

    checked_request(
        session.post(
            f"{KANIDM_URL}/v1/auth",
            json={"step": {"init": USERNAME}},
            timeout=30,
        ),
        "Kanidm authentication initialization",
    )

    response = checked_request(
        session.post(
            f"{KANIDM_URL}/v1/auth",
            json={"step": {"begin": "passwordmfa"}},
            timeout=30,
        ),
        "Kanidm credential mechanism selection",
    )
    state = response.json()["state"]
    while "success" not in state:
        allowed = state["continue"]
        if "totp" in allowed:
            credential = {"totp": totp_code(totp_secret)}
            description = "Kanidm TOTP authentication"
        elif "password" in allowed:
            credential = {"password": KANIDM_PASSWORD}
            description = "Kanidm password authentication"
        else:
            raise AssertionError(f"Unsupported Kanidm auth state: {state}")

        response = checked_request(
            session.post(
                f"{KANIDM_URL}/v1/auth",
                json={"step": {"cred": credential}},
                timeout=30,
            ),
            description,
        )
        state = response.json()["state"]

    return state["success"]


def create_mail_password(user_token):
    response = HTTP_SESSION.get(
        f"{API_URL}/login/oauth",
        allow_redirects=False,
        timeout=30,
    )
    assert response.is_redirect
    browser_authorization_url = response.headers["Location"]

    parsed = urlparse(browser_authorization_url)
    authorization_url = urlunparse(
        parsed._replace(path="/oauth2/authorise", fragment="")
    )
    response = checked_request(
        HTTP_SESSION.get(
            authorization_url,
            headers={"Authorization": f"Bearer {user_token}"},
            allow_redirects=False,
            timeout=30,
        ),
        "OAuth authorization",
    )

    consent_token = response.json()["ConsentRequested"]["consent_token"]
    response = checked_request(
        HTTP_SESSION.post(
            f"{KANIDM_URL}/oauth2/authorise/permit",
            headers={"Authorization": f"Bearer {user_token}"},
            json=consent_token,
            allow_redirects=False,
            timeout=30,
        ),
        "OAuth consent",
    )
    callback_url = response.headers["Location"]
    response = HTTP_SESSION.get(
        callback_url,
        allow_redirects=False,
        timeout=30,
    )
    assert response.is_redirect

    response = checked_request(
        HTTP_SESSION.post(
            f"{API_URL}/user/email-passwords/create",
            data={"display_name": "Test"},
            timeout=30,
        ),
        "mail password creation",
    )
    match = re.search(r"<code[^>]*>([^<]+)</code>", response.text)
    assert match is not None
    return html.unescape(match.group(1)).strip()


def test_mail_delivery(mail_password):
    context = ssl.create_default_context(cafile=CA_FILE)
    address = f"{USERNAME}@{MAILSERVER}"

    message = EmailMessage()
    message["From"] = address
    message["To"] = address
    message["Subject"] = SUBJECT
    message.set_content("joking\n")

    with smtplib.SMTP_SSL(MAILSERVER, 465, context=context, timeout=30) as smtp:
        smtp.login(address, mail_password)
        smtp.send_message(message)

    for _attempt in range(30):
        try:
            with imaplib.IMAP4_SSL(MAILSERVER, 993, ssl_context=context) as imap:
                imap.login(address, mail_password)
                imap.select("INBOX")
                status, messages = imap.search(None, "SUBJECT", f'"{SUBJECT}"')
                if status == "OK" and messages[0]:
                    return
        except imaplib.IMAP4.error:
            pass
        time.sleep(1)

    raise AssertionError("The test message was not delivered to the IMAP inbox")


def main():
    totp_secret = create_user_and_set_identity_password()
    user_token = kanidm_user_auth_token(totp_secret)
    mail_password = create_mail_password(user_token)
    test_mail_delivery(mail_password)


if __name__ == "__main__":
    main()
