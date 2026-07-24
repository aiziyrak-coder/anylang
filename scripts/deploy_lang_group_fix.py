#!/usr/bin/env python3
"""Deploy language fix + group add/join + URL translation skip."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/integrations/translation.py",
    "backend/app/services/group_admin.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3500:] if len(text) > 3500 else text)
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

    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build api worker",
        timeout=1200,
    )
    sudo(
        c,
        "sleep 4; curl -sS -o /dev/null -w 'health:%{http_code} langs:%{http_code}\\n' "
        "https://anylang.uz/health https://anylang.uz/api/v1/languages",
        timeout=60,
    )
    c.close()
    print("deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
