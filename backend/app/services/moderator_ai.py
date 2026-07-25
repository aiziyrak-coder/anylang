"""Moderator AI — spam o‘chirish, haqorat bloklash, reklama aniqlash."""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass

import httpx
from redis.asyncio import Redis

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

ABUSE_STRIKE_LIMIT = 3
ABUSE_STRIKE_TTL = 24 * 3600
MUTE_TTL = 30 * 60
FLOOD_WINDOW = 20
FLOOD_LIMIT = 6

_MESSAGES = {
    "uz": {
        "spam": "Moderator AI: spam xabar o‘chirildi.",
        "abuse": "Moderator AI: haqoratli matn bloklandi.",
        "ad": "Moderator AI: reklamali xabar aniqlanib, o‘chirildi.",
        "muted": "Moderator AI: qoida buzilishi tufayli vaqtincha yozish cheklandi.",
        "generic": "Moderator AI: xabar qoidalarga mos emas.",
    },
    "ru": {
        "spam": "Moderator AI: спам-сообщение удалено.",
        "abuse": "Moderator AI: оскорбительный текст заблокирован.",
        "ad": "Moderator AI: реклама обнаружена и удалена.",
        "muted": "Moderator AI: из-за нарушений временно ограничена отправка.",
        "generic": "Moderator AI: сообщение не соответствует правилам.",
    },
    "en": {
        "spam": "Moderator AI: spam message removed.",
        "abuse": "Moderator AI: abusive language was blocked.",
        "ad": "Moderator AI: advertising detected and removed.",
        "muted": "Moderator AI: sending temporarily restricted due to violations.",
        "generic": "Moderator AI: message does not meet community rules.",
    },
}

# Lightweight keyword / pattern rules (uz/ru/en). Not exhaustive — AI fills gaps.
_ABUSE_PATTERNS = [
    r"\b(fuck|fucking|shit|bitch|asshole|idiot|moron)\b",
    r"\b(сука|бляд|хуй|пизд|ебан|мудак|дебил|идиот)\b",
    r"\b(ahmoq|jinni|onang|otangni|qo'?tos|qotos|yeban|yebgan)\b",
    r"\b(гандон|мразь|тварь)\b",
]

_SPAM_PATTERNS = [
    r"(.)\1{9,}",  # aaaaaaaaa
    r"(https?://|t\.me/|telegram\.me/)[^\s]{8,}.*(https?://|t\.me/)",
    r"\b(free\s*crypto|airdrop|double\s*your\s*money|binance\s*giveaway)\b",
    r"\b(1000%\s*profit|guaranteed\s*profit)\b",
    r"(whats?\s*app|viber|telegram)\s*[:\-]?\s*\+?\d{8,}",
]

_AD_PATTERNS = [
    r"\b(reklama|реклама|promo\s*code|промокод)\b",
    r"\b(subscribe\s+to\s+my|подпишись|obuna\s+bo'?ling)\b",
    r"(instagram\.com/|tiktok\.com/)[^\s]{3,}.*(follow|подп|obuna)",
    r"\b(cheap\s+meds|casino\s+bonus|xxx)\b",
    r"\b(dm\s+for\s+price\s+list).{0,40}(whats?\s*app|telegram)\b",
]


@dataclass
class ModerationVerdict:
    allowed: bool
    category: str  # ok | spam | abuse | ad
    message: str
    score: float = 0.0
    source: str = "rules"  # rules | ai


def _locale(code: str) -> str:
    c = (code or "uz").lower().split("_")[0]
    if c in {"ru", "rus"}:
        return "ru"
    if c in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


def _msg(loc: str, key: str) -> str:
    return _MESSAGES.get(loc, _MESSAGES["uz"]).get(key, _MESSAGES["uz"]["generic"])


def _norm(text: str) -> str:
    t = (text or "").strip().lower()
    t = re.sub(r"\s+", " ", t)
    return t


def _rule_hit(text: str, patterns: list[str]) -> bool:
    for p in patterns:
        try:
            if re.search(p, text, flags=re.IGNORECASE):
                return True
        except re.error:
            continue
    return False


def _rules_classify(text: str) -> tuple[str, float]:
    """Return (category, confidence). category in ok|spam|abuse|ad."""
    if not text or len(text) < 2:
        return "ok", 0.0
    if _rule_hit(text, _ABUSE_PATTERNS):
        return "abuse", 0.92
    if _rule_hit(text, _SPAM_PATTERNS):
        return "spam", 0.88
    # Very short repeated promo lines
    if len(text) > 40 and _rule_hit(text, _AD_PATTERNS):
        # Ads in 1:1 B2B can be legitimate product talk — only strong patterns
        return "ad", 0.75
    # Flood-like: same token repeated
    tokens = text.split()
    if len(tokens) >= 8:
        uniq = len(set(tokens))
        if uniq <= 2:
            return "spam", 0.8
    return "ok", 0.0


async def _openai_classify(text: str, lang: str) -> dict | None:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        return None
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    system = (
        "You are AnyLang Moderator AI for a cross-border B2B messenger.\n"
        "Classify the user message. Categories:\n"
        "- abuse: insults, hate, harassment, severe profanity aimed at a person\n"
        "- spam: scam links, flooding, crypto pumps, mass unsolicited junk\n"
        "- ad: pure advertising / cold promo unrelated to an ongoing trade chat "
        "(NOT normal B2B product discussion, quotes, MOQ, shipping terms)\n"
        "- ok: normal conversation or legitimate trade talk\n"
        'Return JSON only: {"category":"ok|abuse|spam|ad","confidence":0-1,"reason":"short"}\n'
        "Be conservative on 'ad' — manufacturers discussing products is OK.\n"
        f"User language hint: {lang}."
    )
    payload = {
        "model": model,
        "temperature": 0.0,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": text[:2500]},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                OPENAI_CHAT_URL,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
        ).strip()
        parsed = json.loads(content) if content else {}
        if not isinstance(parsed, dict):
            return None
        cat = str(parsed.get("category") or "ok").strip().lower()
        if cat not in {"ok", "abuse", "spam", "ad"}:
            cat = "ok"
        conf = float(parsed.get("confidence") or 0)
        conf = max(0.0, min(1.0, conf))
        return {"category": cat, "confidence": conf, "reason": str(parsed.get("reason") or "")[:120]}
    except Exception as exc:
        logger.warning("moderator_ai openai failed: %s", exc)
        return None


async def _check_mute(redis: Redis | None, user_id: int, loc: str) -> None:
    if redis is None:
        return
    try:
        if await redis.exists(f"mod_mute:{user_id}"):
            raise AppError(
                message=_msg(loc, "muted"),
                error_code="MODERATION_MUTED",
                status_code=429,
            )
    except AppError:
        raise
    except Exception as exc:
        logger.warning("moderator_ai mute check failed: %s", exc)


async def _record_abuse_strike(redis: Redis | None, user_id: int) -> None:
    if redis is None:
        return
    key = f"mod_abuse:{user_id}"
    try:
        n = await redis.incr(key)
        if n == 1:
            await redis.expire(key, ABUSE_STRIKE_TTL)
        if int(n) >= ABUSE_STRIKE_LIMIT:
            await redis.setex(f"mod_mute:{user_id}", MUTE_TTL, "1")
            await redis.delete(key)
    except Exception as exc:
        logger.warning("moderator_ai abuse strike failed: %s", exc)


async def _check_flood(redis: Redis | None, user_id: int, text: str, loc: str) -> None:
    if redis is None:
        return
    fingerprint = re.sub(r"\W+", "", text.lower())[:80] or "x"
    key = f"mod_flood:{user_id}:{fingerprint}"
    try:
        n = await redis.incr(key)
        if n == 1:
            await redis.expire(key, FLOOD_WINDOW)
        if int(n) >= FLOOD_LIMIT:
            raise AppError(
                message=_msg(loc, "spam"),
                error_code="MODERATION_SPAM",
                status_code=400,
                extra={"category": "spam", "moderator": True},
            )
    except AppError:
        raise
    except Exception as exc:
        logger.warning("moderator_ai flood check failed: %s", exc)


async def moderate_text(
    *,
    text: str,
    locale: str = "uz",
    redis: Redis | None = None,
    user_id: int | None = None,
    context: str = "chat",
) -> ModerationVerdict:
    """Raise AppError if blocked; otherwise return ok verdict.

    For callers that prefer non-raising API — use `evaluate_text`.
    """
    verdict = await evaluate_text(
        text=text,
        locale=locale,
        redis=redis,
        user_id=user_id,
        context=context,
    )
    if not verdict.allowed:
        code = {
            "spam": "MODERATION_SPAM",
            "abuse": "MODERATION_ABUSE",
            "ad": "MODERATION_AD",
        }.get(verdict.category, "MODERATION_BLOCKED")
        raise AppError(
            message=verdict.message,
            error_code=code,
            status_code=400,
            extra={
                "category": verdict.category,
                "moderator": True,
                "source": verdict.source,
            },
        )
    return verdict


async def evaluate_text(
    *,
    text: str,
    locale: str = "uz",
    redis: Redis | None = None,
    user_id: int | None = None,
    context: str = "chat",
) -> ModerationVerdict:
    loc = _locale(locale)
    raw = (text or "").strip()
    if not raw:
        return ModerationVerdict(allowed=True, category="ok", message="", score=0.0)

    if user_id is not None:
        await _check_mute(redis, user_id, loc)
        await _check_flood(redis, user_id, raw, loc)

    normalized = _norm(raw)
    cat, conf = _rules_classify(normalized)
    source = "rules"

    # Ads: in feed, be stricter; in chat, only block strong rule hits or AI high conf
    need_ai = cat == "ok" or (cat == "ad" and conf < 0.85) or (0.55 <= conf < 0.9)
    if need_ai and len(normalized) >= 12:
        ai = await _openai_classify(raw, loc)
        if ai:
            source = "ai"
            ai_cat = ai["category"]
            ai_conf = float(ai["confidence"])
            if ai_cat != "ok" and ai_conf >= 0.72:
                cat, conf = ai_cat, ai_conf
            elif cat != "ok" and ai_cat == "ok" and ai_conf >= 0.7:
                # AI says OK overrides weak rule ad hit
                if cat == "ad" and conf < 0.9:
                    cat, conf = "ok", ai_conf

    if context == "feed" and cat == "ok":
        # Extra pass for feed titles+bodies already concatenated by caller
        pass

    if cat == "ok":
        return ModerationVerdict(
            allowed=True, category="ok", message="", score=conf, source=source
        )

    if cat == "abuse" and user_id is not None:
        await _record_abuse_strike(redis, user_id)

    return ModerationVerdict(
        allowed=False,
        category=cat,
        message=_msg(loc, cat if cat in _MESSAGES["uz"] else "generic"),
        score=conf,
        source=source,
    )
