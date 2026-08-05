# -*- coding: utf-8 -*-
"""Deploy current backend/admin code to DEV stack only (prod untouched)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS") or os.environ.get("SSH_PASS")
if not PASS:
    print("Set ANYLANG_SSH_PASS", file=sys.stderr)
    sys.exit(1)

HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
REMOTE = "/home/admin_root/anylang"
ROOT = Path(r"E:\Anylang")

# Sync whole backend app + admin (compose rebuild picks them up)
SYNC_DIRS = [
    ("backend/app", f"{REMOTE}/backend/app"),
    ("backend/alembic", f"{REMOTE}/backend/alembic"),
    ("admin", f"{REMOTE}/admin"),
]
SYNC_FILES = [
    ("deploy/docker-compose.dev.yml", f"{REMOTE}/deploy/docker-compose.dev.yml"),
    ("backend/Dockerfile", f"{REMOTE}/backend/Dockerfile"),
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 400) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    safe = text.encode("ascii", "replace").decode("ascii")
    print(safe[-3500:] if len(safe) > 3500 else safe)
    return text


def _put_tree(sftp: paramiko.SFTPClient, local: Path, remote: str) -> None:
    try:
        sftp.stat(remote)
    except FileNotFoundError:
        # mkdir -p via nested create
        parts = remote.strip("/").split("/")
        cur = ""
        for p in parts:
            cur += "/" + p
            try:
                sftp.stat(cur)
            except FileNotFoundError:
                sftp.mkdir(cur)
    if local.is_file():
        sftp.put(str(local), remote)
        return
    for path in local.rglob("*"):
        if path.is_dir():
            continue
        if any(x in path.parts for x in (".git", "node_modules", ".next", "__pycache__", ".venv")):
            continue
        rel = path.relative_to(local).as_posix()
        rpath = f"{remote}/{rel}"
        rdir = rpath.rsplit("/", 1)[0]
        try:
            sftp.stat(rdir)
        except FileNotFoundError:
            parts = rdir.strip("/").split("/")
            cur = ""
            for p in parts:
                cur += "/" + p
                try:
                    sftp.stat(cur)
                except FileNotFoundError:
                    sftp.mkdir(cur)
        sftp.put(str(path), rpath)


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()
    for rel, remote in SYNC_FILES:
        print("put file", rel)
        sftp.put(str(ROOT / rel), remote)
    for rel, remote in SYNC_DIRS:
        print("sync", rel)
        _put_tree(sftp, ROOT / rel, remote)
    sftp.close()

    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.dev.yml --env-file .env.dev "
        "up -d --build api worker admin",
        timeout=400,
    )
    sudo(
        c,
        "curl -sS -m 15 -o /dev/null -w 'dev_health:%{http_code}\\n' "
        "http://127.0.0.1:8205/health; "
        "curl -sS -m 15 -o /dev/null -w 'dev_public:%{http_code}\\n' "
        "https://dev.anylang.uz/health || true",
    )
    c.close()
    print("DEV deploy done (production untouched)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
