#!/usr/bin/env python3
"""Deploy auth register OTP fixes and clear rate limits."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = "87.192.230.208"
BASE = "https://anylang.uz"


def main() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=20)
    sftp = c.open_sftp()
    for local, remote in [
        (
            r"E:\Anylang\backend\app\services\auth.py",
            "/home/admin_root/anylang/backend/app/services/auth.py",
        ),
        (
            r"E:\Anylang\backend\app\api\v1\auth.py",
            "/home/admin_root/anylang/backend/app/api/v1/auth.py",
        ),
    ]:
        sftp.put(local, remote)
        print("uploaded", remote)
    sftp.close()

    rebuild = (
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api"
    )
    _, o, e = c.exec_command(
        f"echo '{PASS}' | sudo -S bash -lc {repr(rebuild)}", timeout=600
    )
    print(o.read().decode()[-2000:])
    print(e.read().decode()[-500:])

    # clear rate limits
    _, o, _ = c.exec_command(
        f"echo '{PASS}' | sudo -S docker exec anylang-redis-1 "
        "redis-cli --scan --pattern 'auth:*'",
        timeout=30,
    )
    keys = [k.strip() for k in o.read().decode().splitlines() if k.strip()]
    for k in keys:
        c.exec_command(
            f"echo '{PASS}' | sudo -S docker exec anylang-redis-1 redis-cli DEL '{k}'",
            timeout=15,
        )
    print("cleared", keys)

    # wait healthy
    for _ in range(20):
        _, o, _ = c.exec_command(
            f"echo '{PASS}' | sudo -S docker inspect -f "
            "'{{.State.Health.Status}}' anylang-api-1",
            timeout=15,
        )
        status = o.read().decode().strip()
        print("health:", status)
        if status == "healthy":
            break
        time.sleep(2)

    c.close()

    email = f"regfix_{int(time.time())}@example.com"
    body = json.dumps(
        {
            "email": email,
            "password": "TestPass123!",
            "full_name": "Fix Test",
            "native_language": "uz",
            "app_language": "uz_UZ",
            "country": "UZ",
            "birth_date": "2000-01-15",
            "gender": "female",
            "terms_accepted": True,
        }
    ).encode()
    req = urllib.request.Request(
        BASE + "/api/v1/auth/register",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read().decode())
            print("REGISTER", r.status, data)
            otp = data.get("debug_otp")
            assert otp and len(otp) == 6, data
            vreq = urllib.request.Request(
                BASE + "/api/v1/auth/verify-email",
                data=json.dumps({"email": email, "code": otp}).encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(vreq, timeout=30) as vr:
                print("VERIFY", vr.status, vr.read().decode()[:180])
    except urllib.error.HTTPError as e:
        print("ERR", e.code, e.read().decode())
        raise


if __name__ == "__main__":
    main()
