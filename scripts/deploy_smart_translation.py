#!/usr/bin/env python3
"""Deploy Smart Translation domain support + migrate."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/alembic/versions/f3a4b5c6d7e8_smart_translation_domain.py",
    "backend/app/models/user.py",
    "backend/app/integrations/translation.py",
    "backend/app/services/messages.py",
    "backend/app/services/business.py",
    "backend/app/services/users.py",
    "backend/app/services/live.py",
    "backend/app/schemas/user.py",
    "backend/app/schemas/business.py",
    "backend/app/api/v1/users.py",
    "backend/app/api/v1/chats.py",
]


def ensure(sftp: paramiko.SFTPClient, remote: str) -> None:
    parts = remote.strip("/").split("/")
    cur = ""
    for p in parts:
        cur += "/" + p
        try:
            sftp.stat(cur)
        except OSError:
            try:
                sftp.mkdir(cur)
            except OSError:
                pass


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-3500:])
    print("exit", code)
    return code


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    for rel in FILES:
        local = ROOT / rel.replace("/", os.sep)
        remote = f"{REMOTE}/{rel}"
        ensure(sftp, remote.rsplit("/", 1)[0])
        sftp.put(str(local), remote)
        print("put", rel)
    sftp.close()
    code = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api worker && "
        "sleep 12 && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T api alembic upgrade head",
        timeout=1800,
    )
    c.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
