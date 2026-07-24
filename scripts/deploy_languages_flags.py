#!/usr/bin/env python3
"""Deploy languages table + flag URLs API; publish flag PNGs."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/models/__init__.py",
    "backend/app/models/language.py",
    "backend/app/services/language_catalog.py",
    "backend/app/services/languages.py",
    "backend/app/services/live.py",
    "backend/app/schemas/live.py",
    "backend/app/api/v1/languages.py",
    "backend/app/api/v1/router.py",
    "backend/alembic/versions/c8d9e0f1a2b3_languages_flags.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-4000:] if len(text) > 4000 else text)
    return text


def ensure_remote_dir(sftp: paramiko.SFTPClient, remote: str) -> None:
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


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        local = ROOT / rel.replace("/", os.sep)
        remote = f"{REMOTE}/{rel}"
        ensure_remote_dir(sftp, str(Path(remote).parent).replace("\\", "/"))
        sftp.put(str(local), remote)
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
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T api alembic upgrade head",
        timeout=180,
    )
    sudo(
        c,
        "sleep 3; curl -sS https://anylang.uz/api/v1/languages | head -c 400; echo; "
        "curl -sS -o /dev/null -w 'live:%{http_code}\\n' "
        "https://anylang.uz/api/v1/live/languages",
        timeout=60,
    )
    c.close()
    print("API languages deploy done — now run publish_flags.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
