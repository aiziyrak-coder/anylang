#!/usr/bin/env python3
"""Deploy chat Telegram features (group admin + message features)."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/models/chat.py",
    "backend/app/models/__init__.py",
    "backend/app/schemas/chat.py",
    "backend/app/schemas/payment.py",
    "backend/app/services/chats.py",
    "backend/app/services/messages.py",
    "backend/app/services/group_admin.py",
    "backend/app/services/message_features.py",
    "backend/app/services/payments.py",
    "backend/app/api/v1/chats.py",
    "backend/app/api/v1/payments.py",
    "backend/app/ws/endpoint.py",
    "backend/alembic/versions/f6a7b8c9d0e1_chat_features_groups.py",
]


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        local = rf"E:\Anylang\{rel.replace('/', os.sep)}"
        if not os.path.isfile(local):
            print("MISSING", local)
            continue
        remote = f"{REMOTE}/{rel}"
        # ensure remote dir
        remote_dir = "/".join(remote.split("/")[:-1])
        try:
            sftp.stat(remote_dir)
        except FileNotFoundError:
            # mkdir -p via ssh below if needed
            pass
        sftp.put(local, remote)
        print("put", rel)
    sftp.close()

    cmd = (
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api && "
        "docker compose -f docker-compose.prod.yml --env-file .env exec -T api alembic upgrade head"
    )
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, o, e = c.exec_command(full, timeout=1800)
    print(o.read().decode(errors="replace")[-4000:])
    err = e.read().decode(errors="replace")
    cleaned = "\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())
    if cleaned.strip():
        print(cleaned[-2000:])
    code = o.channel.recv_exit_status()
    print("exit", code)

    _, o2, _ = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc "
        f"'sleep 6; curl -sS -m 10 http://127.0.0.1:8105/health; echo; "
        f"docker compose -f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env exec -T api alembic current'",
        timeout=90,
    )
    print(o2.read().decode(errors="replace")[-1500:])
    c.close()
    return 0 if code == 0 else code


if __name__ == "__main__":
    raise SystemExit(main())
