#!/usr/bin/env python3
"""Upload security hardening and rebuild API/admin without wiping prod secrets."""

from __future__ import annotations

import io
import os
import secrets
import sys
import tarfile
import time
from pathlib import Path

import paramiko

ROOT = Path(__file__).resolve().parents[1]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = int(os.environ.get("ANYLANG_SSH_PORT", "2222"))
USER = os.environ.get("ANYLANG_SSH_USER", "admin_root")
PASSWORD = os.environ.get("ANYLANG_SSH_PASS", "")
REMOTE = os.environ.get("ANYLANG_REMOTE_DIR", "/home/admin_root/anylang")

INCLUDE = [
    "backend/app",
    "backend/pyproject.toml",
    "backend/Dockerfile",
    "admin/src",
    "admin/middleware.ts",
    "admin/package.json",
    "admin/package-lock.json",
    "admin/next.config.ts",
    "admin/Dockerfile",
    "admin/tsconfig.json",
    "admin/postcss.config.mjs",
    "admin/tailwind.config.ts",
    "deploy/docker-compose.prod.yml",
    "deploy/env.production.template",
]
SKIP = {"node_modules", ".next", "__pycache__", ".venv", ".git"}


def make_tarball() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel in INCLUDE:
            p = ROOT / rel
            if p.is_file():
                tar.add(p, arcname=rel.replace("\\", "/"))
            elif p.is_dir():
                for f in p.rglob("*"):
                    if not f.is_file():
                        continue
                    if set(f.parts) & SKIP:
                        continue
                    arc = str(f.relative_to(ROOT)).replace("\\", "/")
                    tar.add(f, arcname=arc)
    return buf.getvalue()


def sudo(client: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> str:
    full = f"echo {PASSWORD!r} | sudo -S bash -lc {cmd!r}"
    _, stdout, stderr = client.exec_command(full, timeout=timeout)
    out = (stdout.read() + stderr.read()).decode(errors="replace")
    print(out[-4000:] if len(out) > 4000 else out)
    return out


def main() -> int:
    if not PASSWORD:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1

    payload = make_tarball()
    print(f"packaged {len(payload) / 1024:.1f} KB")
    admin_key = secrets.token_urlsafe(48)

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, port=PORT, username=USER, password=PASSWORD, timeout=30)
    sftp = client.open_sftp()
    with sftp.file(f"{REMOTE}/sec-hardening.tar.gz", "wb") as rf:
        rf.write(payload)
    # remote helper script avoids quoting hell
    remote_sh = f"""#!/bin/bash
set -euo pipefail
cd {REMOTE}
tar xzf sec-hardening.tar.gz
cd deploy
test -f .env
grep -q '^ALLOW_OTP_IN_RESPONSE=' .env && sed -i 's/^ALLOW_OTP_IN_RESPONSE=.*/ALLOW_OTP_IN_RESPONSE=false/' .env || echo 'ALLOW_OTP_IN_RESPONSE=false' >> .env
grep -q '^SMTP_FAIL_OPEN=' .env && sed -i 's/^SMTP_FAIL_OPEN=.*/SMTP_FAIL_OPEN=false/' .env || echo 'SMTP_FAIL_OPEN=false' >> .env
if ! grep -qE '^ADMIN_SECRET_KEY=.{{48,}}' .env; then
  if grep -q '^ADMIN_SECRET_KEY=' .env; then
    sed -i 's|^ADMIN_SECRET_KEY=.*|ADMIN_SECRET_KEY={admin_key}|' .env
  else
    echo 'ADMIN_SECRET_KEY={admin_key}' >> .env
  fi
fi
echo '--- hardened flags ---'
grep -E '^(ALLOW_OTP_IN_RESPONSE|SMTP_FAIL_OPEN)=' .env
test -f ../backend/app/core/rate_limit.py
echo rate_limit_ok
docker compose -f docker-compose.prod.yml --env-file .env build --no-cache api
docker compose -f docker-compose.prod.yml --env-file .env up -d api
docker compose -f docker-compose.prod.yml --env-file .env build admin
docker compose -f docker-compose.prod.yml --env-file .env up -d admin
sleep 10
docker compose -f docker-compose.prod.yml --env-file .env ps
curl -sS http://127.0.0.1:8105/health || true
echo
docker logs anylang-api-1 --tail 40 || true
"""
    with sftp.file(f"{REMOTE}/harden_deploy.sh", "w") as sf:
        sf.write(remote_sh)
    sftp.close()

    print("==> Extract + rebuild")
    sudo(client, f"chmod +x {REMOTE}/harden_deploy.sh && bash {REMOTE}/harden_deploy.sh")
    time.sleep(2)
    _, o, _ = client.exec_command(
        "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/health; echo; "
        "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/openapi.json; echo"
    )
    print("public:", o.read().decode())
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
