# SelfPrivacy NixOS configuration

This is a NixOS config which builds a SelfPrivacy server distribution
based on data provided in `userdata/userdata.json`.

JSON schema is provided in `userdata/schema.json` for reference.

**hardware-configuration.nix is not included.**

Example JSON config:

```json
{
    "backblaze": {
        "accountId": "KEY ID",
        "accountKey": "KEY",
        "bucket": "selfprivacy"
    },
    "bitwarden": {
        "enable": true
    },
    "cloudflare": {
        "apiKey": "KEY"
    },
    "databasePassword": "PASSWORD",
    "domain": "meow-corp.xyz",
    "hashedMasterPassword": "HASHED PASSWORD",
    "hostname": "meow-corp",
    "nextcloud": {
        "enable": true,
        "adminPassword": "PASS",
        "databasePassword": "PASS"
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
    "resticPassword": "PASS",
    "ssh": {
        "enable": true,
        "rootSshKeys": [
            "ssh-ed25519 KEY user@host"
        ],
        "passwordAuthentication": true
    },
    "username": "owner",
    "users": [
        {
            "hashedPassword": "HASHED PASSWORD",
            "username": "tester"
        }
    ]
}
```