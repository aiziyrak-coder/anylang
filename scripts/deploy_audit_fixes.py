#!/usr/bin/env python3
"""Deploy audit fixes: sync, pull, rebuild api/worker/admin, nginx, migrate."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import paramiko

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

SYNC_DIRS = ["backend/app", "backend/alembic", "admin/src", "admin/public", "deploy"]
SYNC_FILES = [
    "backend/Dockerfile",
    "backend/alembic.ini",
    "admin/Dockerfile",
    "admin/package.json",
    "admin/next.config.ts",
    "deploy/docker-compose.prod.yml",
    "deploy/nginx/anylang.uz.conf",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> str:
    _, out, err = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    raw = (out.read() + err.read()).decode("utf-8", errors="replace")
    lines = [ln for ln in raw.splitlines() if not ln.startswith("[sudo]")]
    text = "\n".join(lines)
    print(text[-4500:])
    return text


def put_file(sftp, local: Path, remote: str) -> None:
    parts = remote.strip("/").split("/")
    cur = ""
    for p in parts[:-1]:
        cur += "/" + p
        try:
            sftp.stat(cur)
        except OSError:
            try:
                sftp.mkdir(cur)
            except OSError:
                pass
    sftp.put(str(local), remote)


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    n = 0
    for d in SYNC_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for item in base.rglob("*"):
            if not item.is_file():
                continue
            if "__pycache__" in item.parts or item.suffix in {".pyc"}:
                continue
            if ".next" in item.parts or "node_modules" in item.parts:
                continue
            rel = item.relative_to(ROOT).as_posix()
            put_file(sftp, item, f"{REMOTE}/{rel}")
            n += 1
    for f in SYNC_FILES:
        local = ROOT / f
        if local.exists():
            put_file(sftp, local, f"{REMOTE}/{f}")
            n += 1
    sftp.close()
    print("uploaded", n)

    sudo(
        c,
        f"cd {REMOTE} && git fetch origin && git reset --hard origin/main || true; "
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate "
        "api worker admin",
        timeout=2400,
    )
    sudo(
        c,
        "sleep 15; docker exec anylang-api-1 alembic upgrade head; "
        "cp /home/admin_root/anylang/deploy/nginx/anylang.uz.conf /etc/nginx/sites-available/anylang.uz; "
        "nginx -t && systemctl reload nginx; "
        "curl -sS -m 10 http://127.0.0.1:8105/health; echo; "
        "curl -sS -m 10 -o /dev/null -w 'public:%{http_code}\\n' https://anylang.uz/health; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\\t{{.Status}}'",
        timeout=300,
    )
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
