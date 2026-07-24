#!/usr/bin/env python3
"""Force SFTP sync + docker rebuild (server has no git)."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
SYNC_DIRS = ["backend/app", "backend/alembic", "admin/src", "deploy"]
SYNC_FILES = [
    "backend/requirements.txt",
    "backend/Dockerfile",
    "backend/alembic.ini",
    "admin/package.json",
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


def put_file(sftp: paramiko.SFTPClient, local: Path, remote: str) -> None:
    parent = remote.rsplit("/", 1)[0]
    ensure(sftp, parent)
    sftp.put(str(local), remote)


def sync_tree(sftp: paramiko.SFTPClient, rel: str) -> int:
    base = ROOT / rel
    n = 0
    for item in base.rglob("*"):
        if not item.is_file():
            continue
        if item.suffix in {".pyc", ".pyo"} or "__pycache__" in item.parts:
            continue
        if item.name in {".env", ".env.local"}:
            continue
        if "node_modules" in item.parts or ".next" in item.parts:
            continue
        rel_path = item.relative_to(ROOT).as_posix()
        put_file(sftp, item, f"{REMOTE}/{rel_path}")
        n += 1
    return n


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4500:])
    print("exit", code)
    return code


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    total = 0
    for d in SYNC_DIRS:
        n = sync_tree(sftp, d)
        print(f"synced {d}: {n}")
        total += n
    for f in SYNC_FILES:
        local = ROOT / f
        if local.exists():
            put_file(sftp, local, f"{REMOTE}/{f}")
            total += 1
            print("put", f)
    sftp.close()
    print("total", total)

    code = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api worker admin",
    )
    if code != 0:
        c.close()
        return code

    sudo(
        c,
        "sleep 12; "
        "docker exec anylang-api-1 alembic upgrade head || true; "
        "curl -sS http://127.0.0.1:8105/health; echo; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\\t{{.Status}}'",
    )
    c.close()
    print("SERVER_SYNC_DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
