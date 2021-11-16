# SelfPrivacy NixOS configuration

This is a NixOS config which builds a SelfPrivacy server distribution
based on data provided in `userdata/userdata.json`.

JSON schema is provided in `userdata/schema.json` for reference.

**hardware-configuration.nix is not included.**

Example JSON config:

```json
{
    "backblaze": {
        "accountId": "BACKBLAZE_KEY_ID",
        "accountKey": "BACKBLAZE_ACCOUNT_KEY",
        "bucket": "BACKBLAZE_BUCKET_NAME"
    },
    "api": {
        "token": "API_TOKEN",
        "enableSwagger": false
    },
    "bitwarden": {
        "enable": true
    },
    "cloudflare": {
        "apiKey": "CF_TOKEN"
    },
    "databasePassword": "DB_PASSWORD",
    "domain": "DOMAIN",
    "hashedMasterPassword": "HASHED_PASSWORD",
    "hostname": "DOMAIN",
    "nextcloud": {
        "enable": true,
        "adminPassword": "PASSWORD",
        "databasePassword": "PASSWORD"
    },
    "gitea": {
        "enable": true
    },
    "jitsi": {
        "enable": true
    },
    "ocserv": {
        "enable": true
    },
    "pleroma": {
        "enable": true
    },
    "timezone": "Europe/Moscow",
    "resticPassword": "PASSWORD",
    "ssh": {
        "enable": true,
        "rootSshKeys": [
            "ssh-ed25519 KEY user@host"
        ],
        "passwordAuthentication": true
    },
    "username": "LUSER",
    "users": [
        {
            "hashedPassword": "OTHER_USER_HASHED_PASSWORD",
            "username": "OTHER_USER"
        }
    ]
}
```