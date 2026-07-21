#!/usr/bin/env python3
"""Deploy AnyLang to production server via SFTP + docker compose."""

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
REMOTE_DIR = os.environ.get("ANYLANG_REMOTE_DIR", "/home/admin_root/anylang")

SKIP_DIRS = {
    "node_modules", ".next", ".venv", "__pycache__", ".git", "__MACOSX",
    "build", ".ruff_cache", ".idea",
}
SKIP_FILES = {".env", ".env.local", "flutter_run.log", "anylang-src.tar.gz"}


def should_skip(path: Path) -> bool:
    if path.name in SKIP_FILES:
        return True
    if path.suffix in {".pyc", ".pyo"}:
        return True
    return bool(set(path.parts) & SKIP_DIRS)


def make_tarball() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for item in ROOT.rglob("*"):
            if not item.is_file():
                continue
            rel = item.relative_to(ROOT)
            if should_skip(item):
                continue
            if "ssh_probe" in str(rel):
                continue
            tar.add(item, arcname=str(rel).replace("\\", "/"), recursive=False)
    buf.seek(0)
    return buf.read()


def run(client: paramiko.SSHClient, cmd: str, timeout: int = 600, sudo: bool = False) -> tuple[int, str, str]:
    if sudo:
        cmd = f"echo '{PASSWORD}' | sudo -S bash -lc {repr(cmd)}"
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    code = stdout.channel.recv_exit_status()
    return code, out, err


def main() -> int:
    if not PASSWORD:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1

    secret = secrets.token_urlsafe(48)
    pg_pass = secrets.token_urlsafe(24)
    s3_secret = secrets.token_urlsafe(32)
    admin_pass = f"Any{secrets.token_urlsafe(12)}!9"

    env_content = f"""APP_NAME=AnyLang
APP_ENV=production
DEBUG=false
API_V1_PREFIX=/api/v1
SECRET_KEY={secret}
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=60
POSTGRES_PASSWORD={pg_pass}
DATABASE_URL=postgresql+asyncpg://anylang:{pg_pass}@postgres:5432/anylang
REDIS_URL=redis://redis:6379/0
S3_ENDPOINT_URL=http://minio:9000
S3_ACCESS_KEY=anylang_prod
S3_SECRET_KEY={s3_secret}
S3_BUCKET=anylang
S3_REGION=auto
S3_PUBLIC_BASE_URL=https://anylang.uz/media
SMTP_FROM=AnyLang <noreply@anylang.uz>
SMTP_TLS=true
GOOGLE_CLIENT_IDS=
TRANSLATION_PROVIDER=mock
ALLOW_MOCK_TRANSLATION=true
PAYMENT_PROVIDER=mock
ALLOW_MOCK_PAYMENTS=true
ADMIN_EMAIL=admin@anylang.com
ADMIN_PASSWORD={admin_pass}
ADMIN_SEED_IN_PRODUCTION=true
CORS_ORIGINS=https://anylang.uz,https://www.anylang.uz
TRUSTED_HOSTS=anylang.uz,www.anylang.uz,127.0.0.1,localhost
"""

    print("==> Packaging...")
    payload = make_tarball()
    print(f"    {len(payload)/1024/1024:.1f} MB")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, port=PORT, username=USER, password=PASSWORD, timeout=30)
    sftp = client.open_sftp()

    run(client, f"mkdir -p {REMOTE_DIR}/deploy")
    with sftp.file(f"{REMOTE_DIR}/anylang-src.tar.gz", "wb") as rf:
        rf.write(payload)
    with sftp.file(f"{REMOTE_DIR}/deploy/.env", "w") as ef:
        ef.write(env_content)
    sftp.close()

    print("==> Extracting...")
    code, out, err = run(
        client,
        f"cd {REMOTE_DIR} && tar -xzf anylang-src.tar.gz && chmod +x deploy/install.sh",
    )
    if code != 0:
        print(err)
        return code

    print("==> Docker build (10-20 min)...")
    compose_cmd = (
        f"cd {REMOTE_DIR}/deploy && "
        f"docker compose -f docker-compose.prod.yml --env-file .env up -d --build"
    )
    code, out, err = run(client, compose_cmd, timeout=2400, sudo=True)
    print(out[-12000:])
    if code != 0:
        print("ERR:", err[-6000:], file=sys.stderr)
        return code

    print("==> Nginx...")
    nginx_cmd = (
        f"cp {REMOTE_DIR}/deploy/nginx/anylang.uz.conf /etc/nginx/sites-available/anylang.uz && "
        f"ln -sf /etc/nginx/sites-available/anylang.uz /etc/nginx/sites-enabled/anylang.uz && "
        f"nginx -t && systemctl reload nginx"
    )
    code, out, err = run(client, nginx_cmd, sudo=True)
    print(out, err)
    if code != 0:
        return code

    print("==> Certbot...")
    run(
        client,
        "certbot --nginx -d anylang.uz -d www.anylang.uz --non-interactive --agree-tos "
        "-m admin@anylang.uz --redirect",
        timeout=300,
        sudo=True,
    )

    time.sleep(3)
    _, out, _ = run(client, "curl -sI http://127.0.0.1:8105/health | head -3")
    print("API health:", out)

    print("\n" + "=" * 60)
    print("DEPLOY OK — https://anylang.uz")
    print(f"Admin login: admin@anylang.com / {admin_pass}")
    print("=" * 60)

    # Save credentials locally for user
    creds = ROOT / "deploy" / "CREDENTIALS.local.txt"
    creds.write_text(
        f"anylang.uz admin@anylang.com / {admin_pass}\n",
        encoding="utf-8",
    )
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
