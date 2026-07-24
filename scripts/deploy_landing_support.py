#!/usr/bin/env python3
"""Deploy landing site + support public API, rebuild api, reload nginx."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
WWW = "/var/www/anylang"

LANDING_FILES = [
    "landing/index.html",
    "landing/assets/landing.css",
    "landing/assets/landing.js",
    "landing/download-meta.json",
]

API_FILES = [
    "backend/app/schemas/support.py",
    "backend/app/services/support_chat.py",
    "backend/app/api/v1/support.py",
    "backend/app/api/v1/router.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4000:])
    print("exit", code)
    return code


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


def put(sftp: paramiko.SFTPClient, rel: str) -> None:
    local = ROOT / rel.replace("/", os.sep)
    remote = f"{REMOTE}/{rel}"
    ensure(sftp, remote.rsplit("/", 1)[0])
    sftp.put(str(local), remote)
    print("put", rel)


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    for rel in LANDING_FILES + API_FILES:
        put(sftp, rel)
    sftp.close()

    # Publish landing to nginx root + keep repo copy
    code = sudo(
        c,
        f"mkdir -p {WWW}/assets && "
        f"cp {REMOTE}/landing/index.html {WWW}/index.html && "
        f"cp {REMOTE}/landing/assets/landing.css {WWW}/assets/landing.css && "
        f"cp {REMOTE}/landing/assets/landing.js {WWW}/assets/landing.js && "
        f"cp {REMOTE}/landing/download-meta.json {WWW}/download-meta.json && "
        f"chown -R www-data:www-data {WWW} && "
        f"chmod -R a+rX {WWW} && "
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
        "sleep 10; curl -sS http://127.0.0.1:8105/health; echo; "
        "curl -sS -o /dev/null -w 'public:%{http_code}\\n' "
        "-X POST http://127.0.0.1:8105/api/v1/support/public "
        "-H 'Content-Type: application/json' "
        "-d '{\"message\":\"Salom\",\"history\":[],\"locale\":\"uz\"}'; "
        "curl -sS https://anylang.uz/download/latest.json; echo; "
        "curl -sS -o /dev/null -w 'landing:%{http_code} js:%{http_code}\\n' "
        "https://anylang.uz/ https://anylang.uz/assets/landing.js?v=40",
        timeout=90,
    )
    c.close()
    print("landing + support deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
