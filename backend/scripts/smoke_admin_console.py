"""Smoke: Power Admin Console critical flows against http://127.0.0.1:8000."""

from __future__ import annotations

import asyncio
import sys

import httpx

BASE = "http://127.0.0.1:8000"


async def _otp_for(email: str) -> str:
    async with httpx.AsyncClient(base_url="http://127.0.0.1:8025", timeout=10.0) as mail:
        msgs = (await mail.get("/api/v1/messages")).json()["messages"]
        for m in msgs:
            to = " ".join(
                t.get("Address", "") for t in (m.get("To") or [])
            ).lower()
            if email.lower() in to or True:
                msg_id = m["ID"]
                body = (await mail.get(f"/api/v1/message/{msg_id}")).json()
                text = body.get("Text") or body.get("HTML") or ""
                code = "".join(ch for ch in text if ch.isdigit())[:6]
                if len(code) == 6:
                    return code
        raise AssertionError("OTP not found in Mailpit")


async def main() -> int:
    async with httpx.AsyncClient(base_url=BASE, timeout=30.0) as client:
        r = await client.get("/health")
        assert r.status_code == 200, r.text

        # 1) Admin login
        r = await client.post(
            "/api/v1/admin/auth/login",
            json={"email": "admin@anylang.com", "password": "Admin123!"},
        )
        assert r.status_code == 200, r.text
        admin = r.json()
        assert admin["admin"]["role"] == "superadmin", admin
        ah = {"Authorization": f"Bearer {admin['access_token']}"}

        # 2) Analytics
        r = await client.get("/api/v1/admin/analytics/overview", headers=ah)
        assert r.status_code == 200, r.text
        overview = r.json()
        assert overview, overview

        r = await client.get(
            "/api/v1/admin/analytics/timeseries",
            headers=ah,
            params={"metric": "users_new"},
        )
        assert r.status_code == 200, r.text

        # 3) Payments + subscriptions
        r = await client.get("/api/v1/admin/payments/stats", headers=ah)
        assert r.status_code == 200, r.text
        r = await client.get("/api/v1/admin/payments", headers=ah, params={"limit": 10})
        assert r.status_code == 200, r.text
        r = await client.get("/api/v1/admin/subscriptions", headers=ah, params={"limit": 10})
        assert r.status_code == 200, r.text

        # 4) Register user for soft-delete / restore
        email = f"adminsmoke{int(asyncio.get_running_loop().time())}@gmail.com"
        r = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Admin Smoke",
                "email": email,
                "password": "Qwerty12",
                "birth_date": "1995-01-01",
                "gender": "male",
                "country": "UZ",
                "terms_accepted": True,
                "app_language": "uz_UZ",
                "native_language": "uz",
            },
        )
        assert r.status_code == 201, r.text
        code = await _otp_for(email)
        r = await client.post(
            "/api/v1/auth/verify-email",
            json={"email": email, "code": code},
        )
        assert r.status_code == 200, r.text
        user_token = r.json()["access_token"]
        uh = {"Authorization": f"Bearer {user_token}"}
        user_id = r.json()["user"]["id"]

        # 5) Soft-delete via user API
        r = await client.request(
            "DELETE",
            "/api/v1/users/me",
            headers=uh,
            json={"reason": "smoke_delete"},
        )
        assert r.status_code == 200, r.text

        # Login should fail for deleted
        r = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": "Qwerty12"},
        )
        assert r.status_code == 403, r.text
        assert r.json().get("error_code") == "ACCOUNT_DELETED", r.text

        # 6) Public restore request (non-enumerating response)
        r = await client.post(
            "/api/v1/users/restore-request",
            json={
                "email": email,
                "reason": "Please restore my smoke test account",
            },
        )
        assert r.status_code == 200, r.text
        assert r.json().get("status") == "received", r.text
        req_id = r.json().get("id")

        # 7) Admin approve restore
        r = await client.get(
            "/api/v1/admin/restore-requests",
            headers=ah,
            params={"status": "pending"},
        )
        assert r.status_code == 200, r.text
        items = r.json()["items"]
        if req_id is None:
            match = next((i for i in items if i.get("email") == email), None)
            assert match, items
            req_id = match["id"]
        else:
            assert any(i["id"] == req_id for i in items), items

        r = await client.post(
            f"/api/v1/admin/restore-requests/{req_id}/decide",
            headers=ah,
            json={"approve": True},
        )
        assert r.status_code == 200, r.text

        # Login works again
        r = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": "Qwerty12"},
        )
        assert r.status_code == 200, r.text

        # 8) Admin soft-delete + direct restore
        r = await client.post(
            f"/api/v1/admin/users/{user_id}/soft-delete",
            headers=ah,
            json={"reason": "admin_smoke"},
        )
        assert r.status_code == 200, r.text
        r = await client.post(f"/api/v1/admin/users/{user_id}/restore", headers=ah)
        assert r.status_code == 200, r.text

        # 9) Chats stealth (may be empty) + audit
        r = await client.get("/api/v1/admin/chats", headers=ah, params={"limit": 5})
        assert r.status_code == 200, r.text
        chats = r.json().get("items") or []
        if chats:
            cid = chats[0]["id"]
            r = await client.get(
                f"/api/v1/admin/chats/{cid}/messages",
                headers=ah,
                params={"limit": 20},
            )
            assert r.status_code == 200, r.text
            r = await client.get(
                f"/api/v1/admin/chats/{cid}/export",
                headers=ah,
                params={"format": "json"},
            )
            assert r.status_code == 200, r.text

        r = await client.get("/api/v1/admin/audit-logs", headers=ah, params={"limit": 20})
        assert r.status_code == 200, r.text
        assert len(r.json()["items"]) >= 1

        # 10) Reset password
        r = await client.post(
            f"/api/v1/admin/users/{user_id}/reset-password",
            headers=ah,
        )
        assert r.status_code == 200, r.text
        assert r.json().get("temp_password"), r.text

        # Enumeration: unknown email still 200 generic
        r = await client.post(
            "/api/v1/users/restore-request",
            json={"email": "nobody-does-not-exist@gmail.com", "reason": "smoke enumeration check"},
        )
        assert r.status_code == 200, r.text
        assert r.json().get("status") == "received"
        assert "id" not in r.json() or r.json().get("id") is None

        print("ADMIN CONSOLE SMOKE OK")
        return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except Exception as exc:  # noqa: BLE001
        print(f"ADMIN CONSOLE SMOKE FAIL: {exc}", file=sys.stderr)
        raise
