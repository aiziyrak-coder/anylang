"""End-to-end smoke checks against a running API (http://127.0.0.1:8000)."""

from __future__ import annotations

import asyncio
import sys

import httpx

BASE = "http://127.0.0.1:8000"


async def main() -> int:
    async with httpx.AsyncClient(base_url=BASE, timeout=30.0) as client:
        r = await client.get("/health")
        assert r.status_code == 200, r.text

        r = await client.post(
            "/api/v1/admin/auth/login",
            json={"email": "admin@anylang.com", "password": "Admin123!"},
        )
        assert r.status_code == 200, r.text
        admin_token = r.json()["access_token"]

        r = await client.get(
            "/api/v1/admin/stats",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert r.status_code == 200, r.text

        email = f"smoke_{asyncio.get_event_loop().time():.0f}@gmail.com".replace(".", "")
        # keep a valid gmail-like address
        email = f"smoke{int(asyncio.get_running_loop().time())}@gmail.com"

        r = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Smoke Tester",
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

        # OTP from Mailpit
        async with httpx.AsyncClient(base_url="http://127.0.0.1:8025", timeout=10.0) as mail:
            msgs = (await mail.get("/api/v1/messages")).json()["messages"]
            msg_id = msgs[0]["ID"]
            body = (await mail.get(f"/api/v1/message/{msg_id}")).json()
            text = body.get("Text") or body.get("HTML") or ""
            code = "".join(ch for ch in text if ch.isdigit())[:6]
            assert len(code) == 6, text

        r = await client.post(
            "/api/v1/auth/verify-email",
            json={"email": email, "code": code},
        )
        assert r.status_code == 200, r.text
        token = r.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        r = await client.get("/api/v1/users/me", headers=headers)
        assert r.status_code == 200, r.text
        assert len(r.json()["number"]) == 7

        r = await client.get("/api/v1/subscription/plans")
        assert r.status_code == 200 and len(r.json()["plans"]) == 3

        r = await client.get("/api/v1/numbers/groups", headers=headers)
        assert r.status_code == 200

        r = await client.get("/api/v1/chats", headers=headers)
        assert r.status_code == 200

        r = await client.get("/api/v1/friends", headers=headers)
        assert r.status_code == 200

        r = await client.get("/api/v1/live/languages")
        assert r.status_code == 200

        # Payments mock checkout + confirm
        r = await client.post(
            "/api/v1/payments/checkout",
            headers=headers,
            json={"kind": "subscription", "plan": "premium", "billing_cycle": "monthly"},
        )
        assert r.status_code == 200, r.text
        payment = r.json()
        assert payment.get("mock_confirm") is True
        payment_id = payment["id"]

        r = await client.post(f"/api/v1/payments/{payment_id}/confirm", headers=headers)
        assert r.status_code == 200, r.text
        assert r.json()["payment"]["status"] == "succeeded"
        assert r.json()["user"]["subscription"]["plan"] == "premium"

        # Security headers present
        assert r.headers.get("x-content-type-options") == "nosniff"
        assert r.headers.get("x-frame-options") == "DENY"

        # WebSocket auth with Authorization header
        import websockets

        async with websockets.connect(
            "ws://127.0.0.1:8000/ws",
            additional_headers={"Authorization": f"Bearer {token}"},
        ) as ws:
            await ws.send('{"type":"ping"}')
            pong = await asyncio.wait_for(ws.recv(), timeout=5)
            assert "pong" in pong

        print("SMOKE OK")
        return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except Exception as exc:  # noqa: BLE001
        print("SMOKE FAILED:", exc, file=sys.stderr)
        raise SystemExit(1)
