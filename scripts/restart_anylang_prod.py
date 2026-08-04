#!/usr/bin/env python3
"""Restart AnyLang production stack (api/worker/admin) and verify health."""
from __future__ import annotations

import os
import sys

import paramiko

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    raw = (out.read() + err.read()).decode("utf-8", errors="replace")
    lines = [ln for ln in raw.splitlines() if not ln.startswith("[sudo]")]
    text = "\n".join(lines)
    print(text[-5000:])
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)

    print("=== restart stack ===")
    sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --force-recreate "
        "api worker admin",
        timeout=900,
    )
    print("=== health ===")
    sudo(
        c,
        "sleep 15; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\t{{.Status}}'; "
        "curl -sS -m 10 http://127.0.0.1:8105/health; echo; "
        "curl -sS -m 10 -o /dev/null -w 'public:%{http_code}\\n' https://anylang.uz/health; "
        "curl -sS -m 10 -o /dev/null -w 'landing:%{http_code}\\n' https://anylang.uz/; "
        "curl -sS -m 10 -o /dev/null -w 'admin:%{http_code}\\n' https://anylang.uz/admin/; "
        "curl -sS -m 10 -o /dev/null -w 'apk:%{http_code}\\n' https://anylang.uz/download/anylang-latest.apk; "
        "docker exec anylang-redis-1 redis-cli ping",
        timeout=120,
    )
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
