# -*- coding: utf-8 -*-
"""Sync email delivery code to prod API and optionally set RESEND_API_KEY.

Usage:
  python scripts/deploy_email_otp.py
  python scripts/deploy_email_otp.py --resend-key re_xxxx
"""
from __future__ import annotations

import argparse
import os
import tarfile
import tempfile
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
REMOTE = "/home/admin_root/anylang"
PASS = os.environ["ANYLANG_SSH_PASS"]

SYNC_FILES = [
    "backend/app/integrations/email.py",
    "backend/app/core/config.py",
    "backend/app/core/startup.py",
    "backend/app/schemas/auth.py",
    "backend/app/services/otp.py",
    "backend/app/services/auth.py",
    "backend/app/services/email_guard.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text[-3000:] if len(text) > 3000 else text)
    return text


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--resend-key", default=os.environ.get("RESEND_API_KEY", ""))
    args = ap.parse_args()

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS)

    with tempfile.NamedTemporaryFile(suffix=".tgz", delete=False) as tmp:
        tar_path = tmp.name
    with tarfile.open(tar_path, "w:gz") as tar:
        for rel in SYNC_FILES:
            local = ROOT / rel
            if not local.exists():
                raise SystemExit(f"missing {rel}")
            tar.add(local, arcname=rel)

    sftp = c.open_sftp()
    sftp.put(tar_path, "/tmp/anylang-email-otp.tgz")
    sftp.close()
    os.unlink(tar_path)

    sudo(c, f"tar -xzf /tmp/anylang-email-otp.tgz -C {REMOTE}")

    if args.resend_key:
        key = args.resend_key.strip()
        # Upsert env keys safely
        py = f"""
from pathlib import Path
p = Path('{REMOTE}/deploy/.env')
text = p.read_text(encoding='utf-8', errors='replace')
lines = text.splitlines()
kv = {{
  'RESEND_API_KEY': {key!r},
  'SMTP_FROM': 'AnyLang <noreply@anylang.uz>',
  'SMTP_FAIL_OPEN': 'false',
  'ALLOW_OTP_IN_RESPONSE': 'false',
}}
seen = set()
out = []
for line in lines:
    if not line.strip() or line.strip().startswith('#') or '=' not in line:
        out.append(line)
        continue
    k = line.split('=',1)[0]
    if k in kv:
        out.append(f'{{k}}={{kv[k]}}')
        seen.add(k)
    else:
        out.append(line)
for k,v in kv.items():
    if k not in seen:
        out.append(f'{{k}}={{v}}')
p.write_text('\\n'.join(out)+'\\n', encoding='utf-8')
print('env updated', sorted(kv))
"""
        sudo(c, f"python3 - <<'PY'\n{py}\nPY")

    sudo(
        c,
        f"cd {REMOTE}/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker",
        timeout=1200,
    )
    sudo(
        c,
        "docker logs anylang-api-1 --tail 40 2>&1 | grep -iE 'SMTP|RESEND|email|OTP|Uvicorn|ERROR' || true",
    )
    print("DONE")


if __name__ == "__main__":
    main()
