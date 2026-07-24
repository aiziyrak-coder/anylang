from pathlib import Path

files = [
    Path(r"E:\Anylang\backend\app\services\messages.py"),
    Path(r"E:\Anylang\backend\app\services\message_features.py"),
    Path(r"E:\Anylang\backend\app\services\chats.py"),
]

for p in files:
    t = p.read_text(encoding="utf-8")
    if "user_preferred_lang" not in t and p.name != "chats.py":
        t = t.replace(
            "from app.integrations.translation import _normalize_lang",
            "from app.integrations.translation import _normalize_lang, user_preferred_lang",
        )
    if p.name == "chats.py" and "user_preferred_lang" not in t:
        t = t.replace(
            "from app.integrations.translation import _normalize_lang",
            "from app.integrations.translation import _normalize_lang, user_preferred_lang",
        )
    # Prefer app language for translation targets
    t = t.replace("viewer_language=user.native_language", "viewer_language=user_preferred_lang(user)")
    t = t.replace("viewer_language=peer.native_language", "viewer_language=user_preferred_lang(peer)")
    t = t.replace("viewer_language=viewer.native_language", "viewer_language=user_preferred_lang(viewer)")
    t = t.replace(
        "_normalize_lang(user.native_language)",
        "user_preferred_lang(user)",
    )
    t = t.replace(
        "_normalize_lang(peer.native_language)",
        "user_preferred_lang(peer)",
    )
    t = t.replace("sender_language=user.native_language", "sender_language=user_preferred_lang(user)")
    t = t.replace(
        "_pick_translation_text(m, user.native_language)",
        "_pick_translation_text(m, user_preferred_lang(user))",
    )
    t = t.replace(
        "viewer_lang = _normalize_lang(user.native_language)",
        "viewer_lang = user_preferred_lang(user)",
    )
    # Fix accidental double wraps
    t = t.replace("user_preferred_lang(user_preferred_lang(user))", "user_preferred_lang(user)")
    t = t.replace("user_preferred_lang(user_preferred_lang(peer))", "user_preferred_lang(peer)")
    t = t.replace("user_preferred_lang(user_preferred_lang(viewer))", "user_preferred_lang(viewer)")
    t = t.replace("_normalize_lang(user_preferred_lang(user))", "user_preferred_lang(user)")
    p.write_text(t, encoding="utf-8")
    print(p.name, "ok")
    for i, line in enumerate(t.splitlines(), 1):
        if "native_language" in line and "preferred" not in line:
            print(f"  remain {i}: {line.strip()[:100]}")
