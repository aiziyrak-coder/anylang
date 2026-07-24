#!/usr/bin/env python3
"""Deploy voice STT + chat voice translation."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/integrations/stt.py",
    "backend/app/services/live.py",
    "backend/app/services/messages.py",
    "backend/app/api/v1/chats.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3500:])
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        sftp.put(str(ROOT / rel.replace("/", os.sep)), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()

    sudo(c, "touch /home/admin_root/anylang/backend/app/integrations/stt.py")
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "build --no-cache api worker && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d api worker",
        timeout=1200,
    )
    sudo(
        c,
        "sleep 5; curl -sS -o /dev/null -w 'health:%{http_code}\\n' "
        "http://127.0.0.1:8105/health; "
        "curl -sS -o /dev/null -w 'live_langs:%{http_code}\\n' "
        "https://anylang.uz/api/v1/live/languages",
        timeout=60,
    )
    c.close()
    print("deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
