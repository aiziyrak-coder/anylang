# -*- coding: utf-8 -*-
"""Deploy nginx billing routes + harden Click env for live whitelist."""
from __future__ import annotations

import os
import urllib.request

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
ROOT = r"E:\Anylang"
LOCAL_NGINX = ROOT + r"\deploy\nginx\anylang.uz.conf"
REMOTE_NGINX_SRC = "/home/admin_root/anylang/deploy/nginx/anylang.uz.conf"
REMOTE_NGINX_LIVE = "/etc/nginx/sites-available/anylang.uz"
REMOTE_ENV = "/home/admin_root/anylang/deploy/.env"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS)
sftp = c.open_sftp()
sftp.put(LOCAL_NGINX, REMOTE_NGINX_SRC)
sftp.put(LOCAL_NGINX, "/tmp/anylang.uz.conf")
sftp.close()


def sudo(cmd: str, timeout: int = 120) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text[-2500:] if len(text) > 2500 else text)
    return text


# Patch env: ALLOW_MOCK_PAYMENTS=false (keep test amount 1000 for smoke)
patch = r'''
from pathlib import Path
p = Path("/home/admin_root/anylang/deploy/.env")
lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
kv = {
    "ALLOW_MOCK_PAYMENTS": "false",
    "PAYMENT_PROVIDER": "click",
    "PAYMENT_TEST_AMOUNT_UZS": "1000",
    "PUBLIC_API_BASE_URL": "https://anylang.uz",
}
seen=set(); out=[]
for line in lines:
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        out.append(line); continue
    k=line.split("=",1)[0]
    if k in kv:
        out.append(f"{k}={kv[k]}"); seen.add(k)
    else:
        out.append(line)
for k,v in kv.items():
    if k not in seen: out.append(f"{k}={v}")
p.write_text("\n".join(out)+"\n", encoding="utf-8")
print("env ok", kv)
'''
with open(r"E:\Anylang\scripts\_patch_click_env_tmp.py", "w", encoding="utf-8") as f:
    f.write(patch)
sftp = c.open_sftp()
sftp.put(r"E:\Anylang\scripts\_patch_click_env_tmp.py", "/tmp/patch_click_env.py")
sftp.close()

sudo("python3 /tmp/patch_click_env.py")
sudo(
    f"cp /tmp/anylang.uz.conf {REMOTE_NGINX_LIVE} && "
    f"cp /tmp/anylang.uz.conf /etc/nginx/sites-enabled/anylang.uz && "
    "nginx -t && systemctl reload nginx"
)
sudo(
    "cd /home/admin_root/anylang/deploy && "
    "docker compose -f docker-compose.prod.yml --env-file .env up -d api worker",
    timeout=180,
)

print("=== VERIFY billing/success ===")
with urllib.request.urlopen("https://anylang.uz/billing/success", timeout=15) as r:
    body = r.read().decode("utf-8", "replace")
    print(r.status, "To‘lov" in body or "To'lov" in body or "qabul" in body, body[:200])

print("=== ENV ===")
sudo(
    "docker exec anylang-api-1 printenv | grep -E '^(PAYMENT_|ALLOW_MOCK|CLICK_SERVICE|CLICK_MERCHANT_ID|PUBLIC_API)' "
    "| sed -E 's/(SECRET|KEY)=.*/\\1=***/' | sort"
)
