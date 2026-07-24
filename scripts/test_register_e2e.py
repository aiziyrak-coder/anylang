#!/usr/bin/env python3
"""Clear register rate-limit + E2E register/verify against production."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

import paramiko

HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
PASS = os.environ["ANYLANG_SSH_PASS"]
BASE = "https://anylang.uz"


def ssh_run(cmd: str, timeout: int = 60) -> str:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=20)
    try:
        _, stdout, stderr = c.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode(errors="replace")
        err = stderr.read().decode(errors="replace")
        return (out + ("\n" + err if err else "")).strip()
    finally:
        c.close()


def http_json(method: str, path: str, body: dict | None = None) -> tuple[int, dict | str]:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        BASE + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if body is not None else {},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            try:
                return r.status, json.loads(raw)
            except json.JSONDecodeError:
                return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def main() -> None:
    print("=== SMTP / OTP env ===")
    print(
        ssh_run(
            "grep -iE 'smtp|otp|mail|DEBUG|APP_ENV' "
            "/home/admin_root/anylang/deploy/.env || true"
        )
    )

    print("\n=== Clear auth rate keys ===")
    clear = (
        f"echo '{PASS}' | sudo -S bash -lc "
        "\"docker exec anylang-redis-1 sh -c "
        "'keys=$(redis-cli KEYS \\\"auth:*\\\"); "
        "for k in \\$keys; do redis-cli DEL \\\"\\$k\\\"; done; "
        "echo CLEARED'\""
    )
    print(ssh_run(clear))

    email = f"regtest_{int(time.time())}@example.com"
    print(f"\n=== REGISTER {email} ===")
    code, body = http_json(
        "POST",
        "/api/v1/auth/register",
        {
            "email": email,
            "password": "TestPass123!",
            "full_name": "Reg Test",
            "native_language": "uz",
            "app_language": "uz_UZ",
            "country": "UZ",
            "birth_date": "2000-01-15",
            "gender": "male",
            "terms_accepted": True,
        },
    )
    print(code, body)
    otp = body.get("debug_otp") if isinstance(body, dict) else None
    print("debug_otp:", otp)

    if not otp:
        print("\n=== Recent API logs ===")
        print(
            ssh_run(
                f"echo '{PASS}' | sudo -S docker logs anylang-api-1 --tail 60 2>&1"
            )[-2500:]
        )
        return

    print("\n=== VERIFY ===")
    vcode, vbody = http_json(
        "POST",
        "/api/v1/auth/verify-email",
        {"email": email, "code": otp},
    )
    print(vcode, str(vbody)[:400])


if __name__ == "__main__":
    main()
