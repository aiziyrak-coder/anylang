#!/usr/bin/env python3
"""Deploy support chat API + rebuild api container."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/schemas/support.py",
    "backend/app/services/support_chat.py",
    "backend/app/api/v1/support.py",
    "backend/app/api/v1/router.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> int:
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
        sftp.put(str(local), remote)
        print("put", rel)
    sftp.close()

    code = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api worker",
        timeout=1800,
    )
    if code != 0:
        c.close()
        return code
    sudo(
        c,
        "sleep 8; curl -sS http://127.0.0.1:8105/health; echo; "
        "curl -sS -o /dev/null -w 'support_opts:%{http_code}\\n' "
        "-X OPTIONS http://127.0.0.1:8105/api/v1/support/chat",
        timeout=60,
    )
    c.close()
    print("support deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
