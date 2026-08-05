# -*- coding: utf-8 -*-
"""Bootstrap AnyLang DEV stack on the same VPS as production.

Requires:
  - DNS A record: dev.anylang.uz → VPS IP
  - ANYLANG_SSH_PASS env
  - Existing /home/admin_root/anylang/deploy/.env (prod) to clone secrets from

Creates:
  - deploy/.env.dev (from prod .env + overrides)
  - docker-compose.dev.yml + nginx site
  - starts anylang-dev containers
  - certbot for dev.anylang.uz (if DNS ready)
"""
from __future__ import annotations

import os
import secrets
import string
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

LOCAL_FILES = [
    ("deploy/docker-compose.dev.yml", f"{REMOTE}/deploy/docker-compose.dev.yml"),
    ("deploy/env.dev.template", f"{REMOTE}/deploy/env.dev.template"),
    ("deploy/nginx/dev.anylang.uz.conf", f"{REMOTE}/deploy/nginx/dev.anylang.uz.conf"),
]


def _rand(n: int = 40) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    safe = text.encode("ascii", "replace").decode("ascii")
    print(safe[-4000:] if len(safe) > 4000 else safe)
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()
    for rel, remote in LOCAL_FILES:
        local = ROOT / rel
        print("put", rel)
        sftp.put(str(local), remote)
    sftp.close()

    # Build .env.dev from prod .env if missing
    build_env = r'''
from pathlib import Path
import secrets, string, re

def rand(n=40):
    a = string.ascii_letters + string.digits
    return "".join(secrets.choice(a) for _ in range(n))

prod = Path("/home/admin_root/anylang/deploy/.env")
dev = Path("/home/admin_root/anylang/deploy/.env.dev")
if not prod.exists():
    raise SystemExit("prod .env missing")
if dev.exists():
    print("env.dev already exists — keeping")
else:
    text = prod.read_text(encoding="utf-8", errors="replace")
    pg = rand(32)
    rd = rand(32)
    s3 = rand(32)
    overrides = {
        "APP_ENV": "development",
        "DEBUG": "true",
        "POSTGRES_PASSWORD": pg,
        "REDIS_PASSWORD": rd,
        "DATABASE_URL": f"postgresql+asyncpg://anylang:{pg}@postgres:5432/anylang_dev",
        "REDIS_URL": f"redis://:{rd}@redis:6379/0",
        "S3_ACCESS_KEY": "anylang_dev",
        "S3_SECRET_KEY": s3,
        "S3_BUCKET": "anylang-dev",
        "S3_PUBLIC_BASE_URL": "https://dev.anylang.uz/media",
        "PUBLIC_API_BASE_URL": "https://dev.anylang.uz",
        "CORS_ORIGINS": "https://dev.anylang.uz",
        "TRUSTED_HOSTS": "dev.anylang.uz,127.0.0.1,localhost",
        "SMTP_FROM": "AnyLang Dev <noreply@dev.anylang.uz>",
        "SMTP_FAIL_OPEN": "true",
        "ALLOW_OTP_IN_RESPONSE": "true",
        "ALLOW_MOCK_TRANSLATION": "true",
        "PAYMENT_PROVIDER": "mock",
        "ALLOW_MOCK_PAYMENTS": "true",
        "ADMIN_EMAIL": "admin@dev.anylang.uz",
        "ADMIN_SEED_IN_PRODUCTION": "true",
        "LOG_LEVEL": "DEBUG",
        "SECRET_KEY": rand(48),
        "ADMIN_SECRET_KEY": rand(48),
    }
    lines = []
    seen = set()
    for line in text.splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            lines.append(line)
            continue
        k = line.split("=", 1)[0]
        if k in overrides:
            lines.append(f"{k}={overrides[k]}")
            seen.add(k)
        else:
            lines.append(line)
    for k, v in overrides.items():
        if k not in seen:
            lines.append(f"{k}={v}")
    # Stripe URLs for billing pages on dev
    extra = []
    for k, v in {
        "STRIPE_SUCCESS_URL": "https://dev.anylang.uz/billing/success",
        "STRIPE_CANCEL_URL": "https://dev.anylang.uz/billing/cancel",
    }.items():
        if not any(l.startswith(k + "=") for l in lines):
            extra.append(f"{k}={v}")
        else:
            lines = [f"{k}={v}" if l.startswith(k + "=") else l for l in lines]
    lines.extend(extra)
    dev.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("created .env.dev")
'''
    sftp = c.open_sftp()
    sftp.putfo(
        __import__("io").BytesIO(build_env.encode("utf-8")),
        "/tmp/build_env_dev.py",
    )
    sftp.close()
    sudo(c, "python3 /tmp/build_env_dev.py")

    # Nginx site
    sudo(
        c,
        "cp /home/admin_root/anylang/deploy/nginx/dev.anylang.uz.conf "
        "/etc/nginx/sites-available/dev.anylang.uz && "
        "ln -sfn /etc/nginx/sites-available/dev.anylang.uz "
        "/etc/nginx/sites-enabled/dev.anylang.uz && "
        "nginx -t && systemctl reload nginx",
    )

    # Start stack
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.dev.yml --env-file .env.dev "
        "up -d --build",
        timeout=400,
    )

    # Certbot (needs DNS)
    print("=== certbot (needs DNS A for dev.anylang.uz) ===")
    sudo(
        c,
        "certbot --nginx -d dev.anylang.uz --non-interactive --agree-tos "
        "--register-unsafely-without-email --redirect || "
        "echo CERTBOT_FAILED_check_DNS",
        timeout=180,
    )

    print("=== local health ===")
    sudo(c, "curl -sS -m 10 -o /dev/null -w 'dev_api:%{http_code}\\n' http://127.0.0.1:8205/health")
    c.close()
    print("DONE — next: flutter run (uses DEV). Release AAB always PROD.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
