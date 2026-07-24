#!/usr/bin/env python3
"""Deploy chat groups + sort/pin API."""
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
    "backend/app/services/chats.py",
    "backend/app/services/messages.py",
    "backend/app/api/v1/chats.py",
    "backend/alembic/versions/e5f6a7b8c9d0_chat_groups.py",
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
        remote = f"{REMOTE}/{rel}"
        sftp.put(local, remote)
        print("put", rel)
    sftp.close()

    cmd = (
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api"
    )
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, o, e = c.exec_command(full, timeout=1500)
    print(o.read().decode(errors="replace")[-3000:])
    err = e.read().decode(errors="replace")
    cleaned = "\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())
    if cleaned.strip():
        print(cleaned[-1800:])
    code = o.channel.recv_exit_status()
    print("exit", code)

    _, o2, _ = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc "
        f"'sleep 8; curl -sS -m 10 http://127.0.0.1:8105/health; echo; "
        f"docker compose -f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env exec -T api alembic current'",
        timeout=90,
    )
    print("post:", o2.read().decode(errors="replace")[-1500:])
    c.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
