# -*- coding: utf-8 -*-
"""Harden admin panel: obscure URL, fix login, reset operator password.

Does NOT change public /api/v1 mobile APIs (Play Store safe).
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

ADMIN_PATH = "/ops-x7k2m9q4n8p3"
ADMIN_EMAIL = "islom@gmail.com"
# Strong one-time password — shown at end; change after first login if desired.
ADMIN_PASSWORD = "Al@" + "".join(
    secrets.choice(string.ascii_letters + string.digits) for _ in range(14)
) + "!9"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 420) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text.encode("ascii", "replace").decode("ascii")[-4000:])
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()

    files = [
        ("backend/app/services/admin_auth.py", f"{REMOTE}/backend/app/services/admin_auth.py"),
        ("backend/app/api/v1/admin.py", f"{REMOTE}/backend/app/api/v1/admin.py"),
        ("backend/scripts/reset_admin_password.py", f"{REMOTE}/backend/scripts/reset_admin_password.py"),
        ("admin/src/lib/api.ts", f"{REMOTE}/admin/src/lib/api.ts"),
        ("admin/src/lib/auth.ts", f"{REMOTE}/admin/src/lib/auth.ts"),
        ("admin/src/lib/base-path.ts", f"{REMOTE}/admin/src/lib/base-path.ts"),
        ("admin/src/lib/i18n/uz.ts", f"{REMOTE}/admin/src/lib/i18n/uz.ts"),
        ("admin/src/app/login/page.tsx", f"{REMOTE}/admin/src/app/login/page.tsx"),
        ("admin/src/app/api/auth/login/route.ts", f"{REMOTE}/admin/src/app/api/auth/login/route.ts"),
        ("admin/src/app/api/auth/logout/route.ts", f"{REMOTE}/admin/src/app/api/auth/logout/route.ts"),
        ("admin/next.config.ts", f"{REMOTE}/admin/next.config.ts"),
        ("deploy/docker-compose.prod.yml", f"{REMOTE}/deploy/docker-compose.prod.yml"),
        ("deploy/nginx/anylang.uz.conf", f"{REMOTE}/deploy/nginx/anylang.uz.conf"),
    ]
    for rel, remote in files:
        print("put", rel)
        sftp.put(str(ROOT / rel), remote)
    sftp.close()

    # Ensure ADMIN_BASE_PATH in .env
    patch_env = f'''
from pathlib import Path
p = Path("{REMOTE}/deploy/.env")
lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
kv = {{"ADMIN_BASE_PATH": "{ADMIN_PATH}"}}
seen=set(); out=[]
for line in lines:
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        out.append(line); continue
    k=line.split("=",1)[0]
    if k in kv:
        out.append(f"{{k}}={{kv[k]}}"); seen.add(k)
    else:
        out.append(line)
for k,v in kv.items():
    if k not in seen: out.append(f"{{k}}={{v}}")
p.write_text("\\n".join(out)+"\\n", encoding="utf-8")
print("env ADMIN_BASE_PATH ok")
'''
    sftp = c.open_sftp()
    sftp.putfo(__import__("io").BytesIO(patch_env.encode()), "/tmp/patch_admin_path.py")
    sftp.close()
    sudo(c, "python3 /tmp/patch_admin_path.py")

    # Nginx: copy (already has secret path) + reload
    sudo(
        c,
        f"cp {REMOTE}/deploy/nginx/anylang.uz.conf /etc/nginx/sites-available/anylang.uz && "
        "nginx -t && systemctl reload nginx",
    )

    # Rebuild api (auth fix) + admin (new basePath)
    sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api admin",
        timeout=500,
    )

    sudo(
        c,
        f"docker cp {REMOTE}/backend/scripts/reset_admin_password.py "
        "anylang-api-1:/tmp/reset_admin_password.py && "
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env exec -T -w /app api "
        f"env RESET_ADMIN_EMAIL={ADMIN_EMAIL!r} RESET_ADMIN_PASSWORD={ADMIN_PASSWORD!r} "
        "PYTHONPATH=/app python /tmp/reset_admin_password.py",
        timeout=120,
    )
    # Redis flush admin login keys (best-effort)
    sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env exec -T redis "
        "sh -c 'redis-cli --scan --pattern \"admin:login:*\" | "
        "while read k; do redis-cli del \"$k\"; done' || true",
    )

    sudo(
        c,
        "curl -sS -m 15 -o /dev/null -w 'old_admin:%{http_code}\\n' https://anylang.uz/admin/login; "
        f"curl -sS -m 15 -o /dev/null -w 'new_admin:%{{http_code}}\\n' "
        f"https://anylang.uz{ADMIN_PATH}/login; "
        "curl -sS -m 10 -o /dev/null -w 'api_health:%{http_code}\\n' https://anylang.uz/health",
    )

    c.close()
    print()
    print("=" * 60)
    print("ADMIN LOGIN (keep private — do not commit)")
    print(f"URL:   https://anylang.uz{ADMIN_PATH}/login")
    print(f"Email: {ADMIN_EMAIL}")
    print(f"Pass:  {ADMIN_PASSWORD}")
    print("Old /admin → 404 (intentional)")
    print("Mobile API /api/v1/* unchanged")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
