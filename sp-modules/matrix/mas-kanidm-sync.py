import os
import time
import json
import requests
import psycopg

from psycopg.rows import dict_row
from ulid import ULID


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def getenv(name):
    try:
        return os.environ[name]
    except KeyError:
        print(f"Missing environment variable {name}. You should NOT run this script by hand, please use systemd unit mas-kanidm-sync.service.")
        exit(1)


KANIDM_ULID = ULID.from_str(getenv("KANIDM_ULID"))
KANIDM_UUID = str(KANIDM_ULID.to_uuid())
MAS_URL = getenv("MAS_URL")
KANIDM_URL = getenv("KANIDM_URL")
KANIDM_TOKEN = read_file(getenv("KANIDM_TOKEN_PATH"))
CLIENT_ID = getenv("CLIENT_ID")
CLIENT_SECRET = read_file(getenv("CLIENT_SECRET_PATH"))
MAS_POSTGRES_URL = getenv("MAS_POSTGRES_URL")


while True:
    try:
        r = requests.get(f"{MAS_URL}/.well-known/openid-configuration", timeout=3)
        r.raise_for_status()
        break
    except Exception:
        print(
            f"MAS instance at {MAS_URL} is not responding, trying again in 3 seconds..."
        )
        time.sleep(3)

mas_access_token_req = requests.post(
    f"{MAS_URL}/oauth2/token",
    auth=(CLIENT_ID, CLIENT_SECRET),
    data={"grant_type": "client_credentials", "scope": "urn:mas:admin"},
    timeout=5,
)
mas_access_token_req.raise_for_status()

MAS_ACCESS_TOKEN = mas_access_token_req.json()["access_token"]


def sync_accounts():
    kanidm_persons_request = requests.get(
        f"{KANIDM_URL}/v1/person",
        headers={
            "Authorization": f"Bearer {KANIDM_TOKEN}",
            "Content-Type": "application/json",
        },
        timeout=5,
    )
    kanidm_persons_request.raise_for_status()
    kanidm_persons = kanidm_persons_request.json()

    with psycopg.connect(
        MAS_POSTGRES_URL, autocommit=True, row_factory=dict_row
    ) as pg_conn:
        users = pg_conn.execute(
            "SELECT users.user_id, upstream_oauth_links.subject, users.can_request_admin, users.username FROM users INNER JOIN upstream_oauth_links ON upstream_oauth_links.user_id = users.user_id WHERE upstream_oauth_links.upstream_oauth_provider_id = %s;",
            (KANIDM_UUID,),
        ).fetchall()

        for user_row in users:
            found_in_kanidm = False
            is_admin_in_kanidm = False
            for kanidm_person in kanidm_persons:
                if kanidm_person["attrs"]["uuid"][0] == user_row["subject"]:
                    found_in_kanidm = True
                    for group in kanidm_person["attrs"]["memberof"]:
                        if group.startswith("sp.matrix.admins@"):
                            is_admin_in_kanidm = True
            username = user_row["username"]
            if found_in_kanidm and user_row["can_request_admin"] != is_admin_in_kanidm:
                mas_user_id = str(ULID.from_uuid(user_row["user_id"]))
                print(
                    f"Updating user {username} ({mas_user_id}) can_request_admin field to {is_admin_in_kanidm}"
                )
                response = requests.post(
                    f"{MAS_URL}/api/admin/v1/users/{mas_user_id}/set-admin",
                    data=json.dumps({"admin": is_admin_in_kanidm}),
                    headers={
                        "Authorization": f"Bearer {MAS_ACCESS_TOKEN}",
                        "Content-Type": "application/json",
                    },
                    timeout=5,
                )
                if response.status_code != 200:
                    print(
                        f"ERROR: Failed to update can_request_admin field of user {username}"
                    )
                else:
                    print(f"Updated user {username} ({mas_user_id})")
            elif not found_in_kanidm:
                print(
                    "ERROR: User {username} is in MAS, but doesn't exist in Kanidm. TODO: should we deactivate it?"
                )


while True:
    try:
        sync_accounts()
    except Exception as e:
        print("Failed to sync MAS and Kanidm admin rights:")
        print(e)

    time.sleep(30)
