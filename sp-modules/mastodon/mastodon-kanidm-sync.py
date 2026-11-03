import json
import os
import sys
import time

import psycopg
import requests
from psycopg.rows import dict_row


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def getenv(name):
    try:
        return os.environ[name]
    except KeyError:
        print(
            f"Missing environment variable {name}. You should NOT run this script by hand, please use systemd unit mastodon-kanidm-sync.service."
        )
        sys.exit(1)


def sync_mastodon():
    response = requests.get(
        f"{getenv('KANIDM_URL')}/v1/person",
        headers={
            "Authorization": f"Bearer {read_file(getenv('KANIDM_TOKEN_PATH')).strip()}",
            "Content-Type": "application/json",
        },
        timeout=5,
    )
    response.raise_for_status()
    persons = response.json()
    if not isinstance(persons, list):
        raise ValueError("Expected a Kanidm person list")
    groups_by_name = {}
    for person in persons:
        attrs = person["attrs"]
        groups = {group.split("@", 1)[0] for group in attrs["memberof"]}
        for name in attrs["name"]:
            groups_by_name[name] = groups

    # only revoke roles previously managed by this sync.
    cache_path = getenv("USER_ROLES_CACHE_PATH")
    try:
        managed_users = set(json.loads(read_file(cache_path)))
    except FileNotFoundError:
        managed_users = set()

    with psycopg.connect(
        dbname=getenv("POSTGRES_DBNAME"),
        user=getenv("POSTGRES_USER"),
        host=getenv("POSTGRES_HOST"),
        row_factory=dict_row,
    ) as conn:
        users = conn.execute(
            """
            SELECT identities.uid, users.id, user_roles.name AS role
            FROM users
            JOIN identities ON users.id = identities.user_id
            LEFT JOIN user_roles ON users.role_id = user_roles.id
            WHERE identities.provider = %s;
            """,
            ("openid_connect",),
        ).fetchall()
        roles = {
            row["name"]: row["id"]
            for row in conn.execute("SELECT id, name FROM user_roles;").fetchall()
        }

        for user in users:
            uid = user["uid"]
            groups = groups_by_name.get(uid)
            role = None
            if groups is not None:
                if "sp.mastodon.owners" in groups:
                    role = "Owner"
                elif groups & {"sp.mastodon.admins", "sp.admins"}:
                    role = "Admin"
                elif "sp.mastodon.moderators" in groups:
                    role = "Moderator"

            if role is not None:
                managed_users.add(uid)
            elif uid in managed_users:
                managed_users.remove(uid)
            else:
                continue

            if user["role"] != role:
                print(f"Updating Mastodon user {uid} role to {role}")
                conn.execute(
                    "UPDATE users SET role_id = %s WHERE id = %s;",
                    (roles[role] if role else None, user["id"]),
                )

    tmp_path = cache_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(sorted(managed_users), f)
    os.replace(tmp_path, cache_path)


def main():
    while True:
        try:
            sync_mastodon()
        except Exception as e:
            print("Failed to sync Mastodon and Kanidm roles:")
            print(e)
        time.sleep(30)


if __name__ == "__main__":
    main()
