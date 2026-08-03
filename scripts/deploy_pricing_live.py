# -*- coding: utf-8 -*-
"""Deploy pricing + billing UI; clear PAYMENT_TEST_AMOUNT_UZS."""
from __future__ import annotations

import json
import os
import tarfile
import tempfile
import urllib.request
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/services/subscription.py",
    "backend/app/main.py",
    "backend/app/payments/pricing.py",
    "backend/app/payments/tax.py",
    "backend/app/payments/fx.py",
    "backend/app/payments/service.py",
    "deploy/env.production.template",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text[-2500:] if len(text) > 2500 else text)
    return text


c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS)

with tempfile.NamedTemporaryFile(suffix=".tgz", delete=False) as tmp:
    tar_path = tmp.name
with tarfile.open(tar_path, "w:gz") as tar:
    for rel in FILES:
        tar.add(ROOT / rel, arcname=rel)

sftp = c.open_sftp()
sftp.put(tar_path, "/tmp/anylang-pricing.tgz")
# env patcher
patch = '''#!/usr/bin/env python3
from pathlib import Path
p = Path("/home/admin_root/anylang/deploy/.env")
lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
kv = {
    "PAYMENT_TEST_AMOUNT_UZS": "",
    "PAYMENT_PROVIDER": "click",
    "ALLOW_MOCK_PAYMENTS": "false",
}
# Keep existing USD_UZS_RATE if set; default ensure present
seen = set()
out = []
for line in lines:
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        out.append(line)
        continue
    k = line.split("=", 1)[0]
    if k == "PAYMENT_TEST_AMOUNT_UZS":
        out.append("PAYMENT_TEST_AMOUNT_UZS=")
        seen.add(k)
    elif k in kv:
        out.append(f"{k}={kv[k]}")
        seen.add(k)
    else:
        out.append(line)
        seen.add(k)
for k, v in kv.items():
    if k not in seen:
        out.append(f"{k}={v}")
if "USD_UZS_RATE" not in seen:
    out.append("USD_UZS_RATE=12500")
p.write_text("\\n".join(out) + "\\n", encoding="utf-8")
print("env patched")
for line in p.read_text().splitlines():
    if line.startswith(("PAYMENT_", "USD_UZS", "ALLOW_MOCK")):
        print(line)
'''
with sftp.file("/tmp/patch_pricing_env.py", "w") as f:
    f.write(patch)
sftp.close()
os.unlink(tar_path)

sudo(c, f"tar -xzf /tmp/anylang-pricing.tgz -C {REMOTE}")
sudo(c, "python3 /tmp/patch_pricing_env.py")
# Force rebuild api (no cache on app layer) by touching
sudo(
    c,
    f"cd {REMOTE}/deploy && "
    "docker compose -f docker-compose.prod.yml --env-file .env build --no-cache api worker && "
    "docker compose -f docker-compose.prod.yml --env-file .env up -d api worker",
    timeout=1200,
)

print("=== plans probe ===")
import time
time.sleep(8)
with urllib.request.urlopen("https://anylang.uz/api/v1/subscription/plans?language=uz_UZ", timeout=30) as r:
    data = json.loads(r.read().decode())
print("currency", data.get("currency"), "tax", data.get("payment_tax_percent"), "rate", data.get("usd_uzs_rate"))
for p in data.get("plans", []):
    if p["code"] == "basic":
        continue
    m1 = next((x for x in p.get("periods", []) if x.get("months") == 1), None)
    print(p["code"], "monthly_price", p.get("monthly_price"), "m1", m1)

print("=== billing success snippet ===")
with urllib.request.urlopen("https://anylang.uz/billing/success", timeout=20) as r:
    html = r.read().decode("utf-8", "replace")
print("styled" if "linear-gradient" in html and "To‘lov qabul qilindi" in html else "CHECK", html[html.find("<h1>"):html.find("</h1>")+5] if "<h1>" in html else html[:120])
