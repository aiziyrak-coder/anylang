#!/usr/bin/env python3
"""E2E: DM + group auto-translate — each peer sees native-language AI text."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

BASE = os.environ.get("ANYLANG_BASE", "https://anylang.uz")


def http(method: str, path: str, body: dict | None = None, token: str | None = None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read().decode()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, {"raw": raw}


def register_verify(tag: str, native: str) -> tuple[str, int]:
    email = f"tr_{tag}_{int(time.time()*1000)}@example.com"
    app_lang = {"uz": "uz_UZ", "en": "us_US", "ru": "ru_RU"}.get(native, "uz_UZ")
    code, body = http(
        "POST",
        "/api/v1/auth/register",
        {
            "email": email,
            "password": "TestPass123!",
            "full_name": f"User {tag}",
            "native_language": native,
            "app_language": app_lang,
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


def wait_translated(token: str, chat_id: int, message_id: int, original: str, timeout_s: float = 45.0):
    deadline = time.time() + timeout_s
    last = None
    while time.time() < deadline:
        code, listing = http(
            "GET", f"/api/v1/chats/{chat_id}/messages?limit=20", token=token
        )
        assert code == 200, listing
        items = listing.get("items") or []
        for it in items:
            if int(it.get("id") or 0) != int(message_id):
                continue
            last = it
            text = (it.get("text") or "").strip()
            orig = (it.get("text_original") or "").strip()
            translations = it.get("translations") or []
            done = any(
                (t.get("status") == "done")
                and (t.get("text") or "").strip()
                and (t.get("text") or "").strip() != original
                for t in translations
            )
            if text and text != original and (done or text != orig):
                return it
        time.sleep(1.2)
    raise AssertionError(f"translation timeout: last={last}")


def main() -> None:
    tok_a, id_a = register_verify("a", "uz")
    tok_b, id_b = register_verify("b", "en")
    tok_c, id_c = register_verify("c", "ru")
    print("users", id_a, id_b, id_c)

    # --- DM ---
    code, chat = http("POST", "/api/v1/chats", {"user_id": id_b}, token=tok_a)
    assert code in (200, 201), chat
    chat_id = chat["id"]
    print("dm", chat_id)

    original = "Salom! Bugun qanday ishlar?"
    code, sent = http(
        "POST",
        f"/api/v1/chats/{chat_id}/messages",
        {
            "client_message_id": f"c{int(time.time()*1000)}",
            "type": "text",
            "text": original,
        },
        token=tok_a,
    )
    assert code == 201, sent
    mid = sent["id"]
    print("dm sender sees:", sent.get("text"))

    translated = wait_translated(tok_b, chat_id, mid, original)
    print("dm recipient text:", translated.get("text"))
    print("dm original:", translated.get("text_original"))
    print("dm translations:", translated.get("translations"))
    assert translated.get("text") != original
    print("DM_TRANSLATION_OK")

    # --- Group (uz → en + ru) ---
    code, group = http(
        "POST",
        "/api/v1/chats/groups",
        {
            "title": f"TrGroup {int(time.time())}",
            "user_ids": [id_b, id_c],
        },
        token=tok_a,
    )
    assert code in (200, 201), group
    gid = group["id"]
    print("group", gid)

    g_original = "Bugun yig'ilish soat uchda boshlanadi."
    code, gsent = http(
        "POST",
        f"/api/v1/chats/{gid}/messages",
        {
            "client_message_id": f"g{int(time.time()*1000)}",
            "type": "text",
            "text": g_original,
        },
        token=tok_a,
    )
    assert code == 201, gsent
    gmid = gsent["id"]

    en_msg = wait_translated(tok_b, gid, gmid, g_original)
    ru_msg = wait_translated(tok_c, gid, gmid, g_original)
    print("group EN:", en_msg.get("text"))
    print("group RU:", ru_msg.get("text"))
    assert en_msg.get("text") != g_original
    assert ru_msg.get("text") != g_original
    assert en_msg.get("text") != ru_msg.get("text")
    print("GROUP_TRANSLATION_OK")
    print("TRANSLATION_OK")


if __name__ == "__main__":
    main()
