#!/usr/bin/env python3
"""E2E: two users different languages → chat message auto-translated via OpenAI."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

BASE = "https://anylang.uz"


def http(method: str, path: str, body: dict | None = None, token: str | None = None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, {"raw": raw}


def register_verify(tag: str, native: str) -> tuple[str, int]:
    email = f"tr_{tag}_{int(time.time())}@example.com"
    code, body = http(
        "POST",
        "/api/v1/auth/register",
        {
            "email": email,
            "password": "TestPass123!",
            "full_name": f"User {tag}",
            "native_language": native,
            "app_language": "uz_UZ" if native == "uz" else "us_US",
            "country": "UZ",
            "birth_date": "2000-01-15",
            "gender": "male",
            "terms_accepted": True,
        },
    )
    assert code == 201, body
    otp = body.get("debug_otp")
    assert otp, body
    code, body = http(
        "POST",
        "/api/v1/auth/verify-email",
        {"email": email, "code": otp},
    )
    assert code == 200, body
    return body["access_token"], body["user"]["id"]


def main() -> None:
    # Clear rate limit first via SSH if needed — try anyway
    tok_a, id_a = register_verify("a", "uz")
    tok_b, id_b = register_verify("b", "en")
    print("users", id_a, id_b)

    code, chat = http("POST", "/api/v1/chats", {"user_id": id_b}, token=tok_a)
    assert code in (200, 201), chat
    chat_id = chat["id"]
    print("chat", chat_id)

    msg_body = {
        "client_message_id": f"c{int(time.time()*1000)}",
        "type": "text",
        "text": "Salom! Bugun qanday ishlar?",
    }
    code, sent = http(
        "POST", f"/api/v1/chats/{chat_id}/messages", msg_body, token=tok_a
    )
    assert code == 201, sent
    print("sender sees:", sent.get("text"))

    code, listing = http(
        "GET", f"/api/v1/chats/{chat_id}/messages?limit=10", token=tok_b
    )
    assert code == 200, listing
    items = listing.get("items") or []
    assert items, listing
    last = items[0]
    print("recipient text:", last.get("text"))
    print("original:", last.get("text_original"))
    print("translations:", last.get("translations"))
    assert last.get("text") and last.get("text") != last.get("text_original"), last
    print("TRANSLATION_OK")


if __name__ == "__main__":
    main()
