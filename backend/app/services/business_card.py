"""Business Card QR — ko‘rgazma uchun kompaniya profil havolasi."""

from __future__ import annotations

BUSINESS_CARD_BASE = "https://anylang.uz/b"


def business_card_url(user_id: int) -> str:
    return f"{BUSINESS_CARD_BASE}/{int(user_id)}"
