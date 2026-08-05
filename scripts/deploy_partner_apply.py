#!/usr/bin/env python3
"""Deploy partner applications feature (API + landing + admin)."""
from __future__ import annotations

import os
import tarfile
import tempfile
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = 2222
USER = "admin_root"
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/models/partner_application.py",
    "backend/app/models/__init__.py",
    "backend/app/schemas/partner_application.py",
    "backend/app/services/partner_applications.py",
    "backend/app/api/v1/partner_applications.py",
    "backend/app/api/v1/router.py",
    "backend/alembic/versions/w1x2y3z4a5b6_partner_applications.py",
    "admin/src/app/dashboard/applications/page.tsx",
    "admin/src/app/dashboard/layout.tsx",
    "admin/src/lib/i18n/uz.ts",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3500:] if len(text) > 3500 else text)
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tar_path = tmp.name
    with tarfile.open(tar_path, "w:gz") as tar:
        for rel in FILES:
            tar.add(ROOT / rel, arcname=rel)
        tar.add(ROOT / "landing", arcname="landing")

    print("Uploading…")
    sftp = c.open_sftp()
    sftp.put(tar_path, "/tmp/anylang-partner-apply.tgz")
    sftp.close()
    os.unlink(tar_path)

    sudo(c, f"mkdir -p {REMOTE} && tar -xzf /tmp/anylang-partner-apply.tgz -C {REMOTE}")
    sudo(
        c,
        "mkdir -p /var/www/anylang && "
        f"rsync -a --delete {REMOTE}/landing/ /var/www/anylang/ && "
        "chown -R www-data:www-data /var/www/anylang && chmod -R a+rX /var/www/anylang",
    )

    print("=== rebuild api ===")
    sudo(
        c,
        f"cd {REMOTE}/deploy && docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build api worker",
        timeout=1200,
    )
    print("=== migrate ===")
    sudo(
        c,
        "docker exec anylang-api-1 alembic upgrade head && docker exec anylang-api-1 alembic current",
        timeout=180,
    )
    print("=== rebuild admin ===")
    sudo(
        c,
        f"cd {REMOTE}/deploy && docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build admin",
        timeout=1200,
    )

    print("=== verify ===")
    for cmd in [
        "curl -sS -o /dev/null -w 'partner_page:%{http_code}\\n' https://anylang.uz/partner-apply/",
        "curl -sS -o /dev/null -w 'partner_js:%{http_code}\\n' https://anylang.uz/partner-apply/partner-apply.js",
        "curl -sS -o /dev/null -w 'check_email:%{http_code}\\n' "
        "'https://anylang.uz/api/v1/partner-applications/check-email?email=test@example.com'",
        "curl -sS -o /dev/null -w 'admin:%{http_code}\\n' https://anylang.uz/admin/dashboard/applications",
    ]:
        sudo(c, cmd)

    c.close()
    print("DONE partner-apply deploy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
