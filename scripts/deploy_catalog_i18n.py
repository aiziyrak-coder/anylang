#!/usr/bin/env python3
"""Deploy partner multilingual form + catalog i18n auto-translate."""
from __future__ import annotations

import os
import sys
import tarfile
import tempfile
from pathlib import Path

import paramiko

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(r"E:\Anylang")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = 2222
USER = "admin_root"
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/models/product.py",
    "backend/app/models/partner_application.py",
    "backend/app/schemas/partner_application.py",
    "backend/app/services/catalog_i18n.py",
    "backend/app/services/partner_applications.py",
    "backend/app/services/products.py",
    "backend/app/services/business.py",
    "backend/app/workers/tasks.py",
    "backend/app/workers/settings.py",
    "backend/alembic/versions/x2y3z4a5b6c7_product_catalog_i18n.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text[-3000:] if len(text) > 3000 else text)
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
        tar.add(ROOT / "landing/partner-apply", arcname="landing/partner-apply")

    sftp = c.open_sftp()
    sftp.put(tar_path, "/tmp/anylang-i18n.tgz")
    sftp.close()
    os.unlink(tar_path)

    sudo(c, f"mkdir -p {REMOTE} && tar -xzf /tmp/anylang-i18n.tgz -C {REMOTE}")
    sudo(
        c,
        f"rsync -a {REMOTE}/landing/partner-apply/ /var/www/anylang/partner-apply/ && "
        "chown -R www-data:www-data /var/www/anylang/partner-apply",
    )
    print("=== rebuild api+worker ===")
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
    )
    print("=== verify ===")
    sudo(
        c,
        "curl -sS -o /dev/null -w 'page:%{http_code} js:%{http_code}\\n' "
        "https://anylang.uz/partner-apply/ "
        "'https://anylang.uz/partner-apply/partner-apply.js?v=4'",
    )
    sudo(
        c,
        "grep -n 'auto_translate_note\\|lang-btn\\|translate_catalog_job' "
        "/var/www/anylang/partner-apply/index.html "
        "/home/admin_root/anylang/backend/app/workers/settings.py | head -20",
    )
    c.close()
    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
