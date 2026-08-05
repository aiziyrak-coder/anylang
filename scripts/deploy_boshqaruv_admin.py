# -*- coding: utf-8 -*-
"""Deploy production admin at /boshqaruv with operator credentials + internal API.

Does NOT change public /api/v1 mobile APIs.
"""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS") or os.environ.get("SSH_PASS")
if not PASS:
    print("Set ANYLANG_SSH_PASS", file=sys.stderr)
    sys.exit(1)

HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = int(os.environ.get("ANYLANG_SSH_PORT", "2222"))
USER = os.environ.get("ANYLANG_SSH_USER", "admin_root")
REMOTE = "/home/admin_root/anylang"
ROOT = Path(r"E:\Anylang")

ADMIN_PATH = "/boshqaruv"
ADMIN_EMAIL = "boshqaruvchilar@anylang.uz"
ADMIN_PASSWORD = "Aa.19980912"
ADMIN_NAME = "Boshqaruvchi"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 600) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text.encode("ascii", "replace").decode("ascii")[-5000:])
    return text


def put_tree(sftp: paramiko.SFTPClient, local: Path, remote: str) -> int:
    n = 0
    for path in local.rglob("*"):
        if not path.is_file():
            continue
        if any(x in path.parts for x in (".git", "node_modules", ".next", "__pycache__")):
            continue
        if path.suffix in {".pyc", ".pyo"}:
            continue
        rel = path.relative_to(local).as_posix()
        rpath = f"{remote}/{rel}"
        rdir = rpath.rsplit("/", 1)[0]
        parts = rdir.strip("/").split("/")
        cur = ""
        for p in parts:
            cur += "/" + p
            try:
                sftp.stat(cur)
            except FileNotFoundError:
                try:
                    sftp.mkdir(cur)
                except OSError:
                    pass
        sftp.put(str(path), rpath)
        n += 1
    return n


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()

    files = [
        "deploy/docker-compose.prod.yml",
        "deploy/nginx/anylang.uz.conf",
        "admin/Dockerfile",
        "admin/next.config.ts",
        "admin/package.json",
        "admin/package-lock.json",
        "admin/tsconfig.json",
        "backend/scripts/reset_admin_password.py",
    ]
    for rel in files:
        local = ROOT / rel
        if local.exists():
            print("put", rel)
            sftp.put(str(local), f"{REMOTE}/{rel}")

    print("sync admin/src …")
    put_tree(sftp, ROOT / "admin" / "src", f"{REMOTE}/admin/src")
    sftp.close()

    # Patch production .env
    patch = f"""
from pathlib import Path
p = Path("{REMOTE}/deploy/.env")
text = p.read_text(encoding="utf-8", errors="replace")
lines = text.splitlines()
kv = {{
    "ADMIN_BASE_PATH": "{ADMIN_PATH}",
    "ADMIN_EMAIL": "{ADMIN_EMAIL}",
    "ADMIN_PASSWORD": {ADMIN_PASSWORD!r},
}}
seen = set()
out = []
for line in lines:
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        out.append(line)
        continue
    k = line.split("=", 1)[0]
    if k in kv:
        out.append(f"{{k}}={{kv[k]}}")
        seen.add(k)
    else:
        out.append(line)
for k, v in kv.items():
    if k not in seen:
        out.append(f"{{k}}={{v}}")
p.write_text("\\n".join(out) + "\\n", encoding="utf-8")
print("env patched", sorted(kv))
"""
    sftp = c.open_sftp()
    sftp.putfo(io.BytesIO(patch.encode("utf-8")), "/tmp/patch_boshqaruv_env.py")
    sftp.close()
    sudo(c, "python3 /tmp/patch_boshqaruv_env.py")

    # Nginx: install conf + reload (certbot SSL blocks are in the repo copy)
    sudo(
        c,
        f"cp /etc/nginx/sites-available/anylang.uz "
        f"/etc/nginx/sites-available/anylang.uz.bak.boshqaruv.$(date +%Y%m%d%H%M%S) && "
        f"cp {REMOTE}/deploy/nginx/anylang.uz.conf /etc/nginx/sites-available/anylang.uz && "
        "nginx -t && systemctl reload nginx",
    )

    # Rebuild admin (+ api if needed for health deps)
    sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate admin",
        timeout=700,
    )

    # Upsert operator account
    sudo(
        c,
        f"docker cp {REMOTE}/backend/scripts/reset_admin_password.py "
        "anylang-api-1:/tmp/reset_admin_password.py && "
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env exec -T -w /app api "
        f"env RESET_ADMIN_EMAIL={ADMIN_EMAIL!r} RESET_ADMIN_PASSWORD={ADMIN_PASSWORD!r} "
        f"RESET_ADMIN_NAME={ADMIN_NAME!r} "
        "PYTHONPATH=/app python /tmp/reset_admin_password.py",
        timeout=120,
    )

    # Clear login rate limits
    sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env exec -T redis "
        "sh -c 'redis-cli --scan --pattern \"admin:login:*\" | "
        "while read k; do redis-cli del \"$k\"; done' || true",
    )

    # Verify
    sudo(
        c,
        "sleep 8; "
        "curl -sS -m 15 -o /dev/null -w 'old_admin:%{http_code}\\n' https://anylang.uz/admin/login; "
        "curl -sS -m 15 -o /dev/null -w 'old_ops:%{http_code}\\n' https://anylang.uz/ops-x7k2m9q4n8p3/login; "
        f"curl -sS -m 15 -o /dev/null -w 'boshqaruv:%{{http_code}}\\n' "
        f"https://anylang.uz{ADMIN_PATH}/login; "
        "curl -sS -m 10 -o /dev/null -w 'api_health:%{http_code}\\n' https://anylang.uz/health; "
        f"curl -sS -m 20 -X POST https://anylang.uz{ADMIN_PATH}/api/auth/login "
        "-H 'Content-Type: application/json' "
        f"-d '{{\"email\":\"{ADMIN_EMAIL}\",\"password\":\"{ADMIN_PASSWORD}\"}}' "
        "-o /tmp/admin_login.json -w 'login:%{http_code}\\n'; "
        "python3 -c \"import json; d=json.load(open('/tmp/admin_login.json')); "
        "print('login_ok', d.get('admin',{}).get('email'), d.get('admin',{}).get('role'))\"",
    )

    c.close()
    print()
    print("=" * 60)
    print("PRODUCTION ADMIN")
    print(f"URL:   https://anylang.uz{ADMIN_PATH}/login")
    print(f"Email: {ADMIN_EMAIL}")
    print(f"Pass:  {ADMIN_PASSWORD}")
    print("/admin and old ops path → 404")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
