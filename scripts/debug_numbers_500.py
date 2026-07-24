#!/usr/bin/env python3
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")


def run(c: paramiko.SSHClient, cmd: str, timeout: int = 90) -> str:
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    return (out + ("\n" + err if err.strip() else "")).strip()


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=25)

    print("=== groups (no auth)")
    print(run(c, "curl -sS -m 15 -w '\\nHTTP:%{http_code}\\n' http://127.0.0.1:8105/api/v1/numbers/groups | tail -c 1200"))

    print("=== catalog (no auth)")
    print(
        run(
            c,
            "curl -sS -m 15 -w '\\nHTTP:%{http_code}\\n' "
            "'http://127.0.0.1:8105/api/v1/numbers/catalog?page=1&limit=20' | tail -c 1500",
        )
    )

    print("=== api logs")
    logs = run(
        c,
        f"echo {PASS!r} | sudo -S docker compose "
        f"-f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env "
        f"logs --tail=120 api",
        timeout=60,
    )
    for ln in logs.splitlines():
        low = ln.lower()
        if any(k in low for k in ("number", "traceback", "error", "exception", "500", "catalog")):
            print(ln[-300:])

    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
