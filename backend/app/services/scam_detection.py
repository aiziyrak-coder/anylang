"""Scam Detection — kompaniya xavf darajasini baholaydi.

Sabablar (AI xabarida):
  - yangi hisob
  - noto‘g‘ri / tasdiqlanmagan hujjatlar
  - ko‘p bloklangan
  - shubhali harakatlar
"""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime, timedelta

import httpx
from redis.asyncio import Redis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.product import Product
from app.models.user import BusinessProfile, User
from app.services import trust_score as trust_score_service

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

NEW_ACCOUNT_DAYS = 30
MANY_BLOCKS_THRESHOLD = 3
HIGH_COMPLAINTS = 2


def _locale(code: str) -> str:
    c = (code or "uz").lower().split("_")[0]
    if c in {"ru", "rus"}:
        return "ru"
    if c in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


_REASON_LABELS = {
    "uz": {
        "new_account": "Yangi hisob",
        "bad_documents": "Noto‘g‘ri yoki tasdiqlanmagan hujjatlar",
        "many_blocks": "Ko‘p foydalanuvchi bloklagan",
        "suspicious_activity": "Shubhali harakatlar",
    },
    "ru": {
        "new_account": "Новый аккаунт",
        "bad_documents": "Неверные или непроверенные документы",
        "many_blocks": "Много блокировок",
        "suspicious_activity": "Подозрительная активность",
    },
    "en": {
        "new_account": "New account",
        "bad_documents": "Incorrect or unverified documents",
        "many_blocks": "Blocked by many users",
        "suspicious_activity": "Suspicious activity",
    },
}

_MESSAGE = {
    "uz": {
        "high": "Bu kompaniyada xavf yuqori.",
        "medium": "Bu kompaniyada xavf o‘rtacha — ehtiyot bo‘ling.",
        "low": "Bu kompaniyada ba’zi ogohlantirishlar bor.",
    },
    "ru": {
        "high": "У этой компании высокий риск.",
        "medium": "У этой компании средний риск — будьте осторожны.",
        "low": "У этой компании есть предупреждения.",
    },
    "en": {
        "high": "This company has high risk.",
        "medium": "This company has medium risk — proceed with caution.",
        "low": "This company has some warnings.",
    },
}


def _account_age_days(user: User) -> int | None:
    created = user.created_at
    if created is None:
        return None
    if created.tzinfo is None:
        created = created.replace(tzinfo=UTC)
    return max(0, (datetime.now(UTC) - created).days)


async def count_blocked_by(redis: Redis | None, user_id: int) -> int:
    if redis is None:
        return 0
    try:
        return int(await redis.scard(f"blocked_by:{user_id}") or 0)
    except Exception as exc:
        logger.warning("scam_detection blocked_by count failed: %s", exc)
        return 0


async def _recent_listings_count(db: AsyncSession, user_id: int, *, days: int = 7) -> int:
    since = datetime.now(UTC) - timedelta(days=days)
    result = await db.execute(
        select(func.count())
        .select_from(Product)
        .where(
            Product.seller_id == user_id,
            Product.status == "published",
            Product.created_at >= since,
        )
    )
    return int(result.scalar() or 0)


def _risk_level(score: int, reason_count: int) -> str:
    if score >= 55 or (score >= 40 and reason_count >= 2):
        return "high"
    if score >= 30:
        return "medium"
    if score >= 15 and reason_count >= 1:
        return "low"
    return "none"


async def _openai_message(
    *,
    locale: str,
    level: str,
    reasons: list[dict],
    company: str,
) -> str | None:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key or level == "none" or not reasons:
        return None
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    lang = {"uz": "Uzbek", "ru": "Russian", "en": "English"}.get(locale, "Uzbek")
    system = (
        "You are AnyTrade Scam Detection. Write ONE short warning sentence. "
        f"Language: {lang}. "
        "Do NOT invent new reasons — only reflect the given ones. "
        "Tone: clear B2B caution. "
        'Example: "Bu kompaniyada xavf yuqori." '
        'JSON only: {"message":"..."}'
    )
    user = json.dumps(
        {
            "company": company,
            "risk_level": level,
            "reasons": [r["key"] for r in reasons],
            "reason_labels": [r["label"] for r in reasons],
        },
        ensure_ascii=False,
    )
    payload = {
        "model": model,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
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
        msg = str(parsed.get("message") or "").strip()
        return msg[:180] if msg else None
    except Exception as exc:
        logger.warning("scam_detection openai failed: %s", exc)
        return None


async def compute_scam_risk(
    db: AsyncSession,
    user: User,
    business: BusinessProfile | None = None,
    *,
    redis: Redis | None = None,
    locale: str = "uz",
    trust: dict | None = None,
) -> dict:
    """Business bo‘lmasa — xavf yo‘q."""
    biz = business if business is not None else user.business
    loc = _locale(locale)
    empty = {
        "risk_level": "none",
        "risk_score": 0,
        "message": "",
        "reasons": [],
        "generated_by": "rules",
        "show_warning": False,
    }
    if biz is None or not user.is_business:
        return empty

    labels = _REASON_LABELS.get(loc, _REASON_LABELS["uz"])
    reasons: list[dict] = []
    score = 0

    age_days = _account_age_days(user)
    certs = [str(c).strip() for c in (biz.certificates or []) if str(c).strip()]
    docs_ok = bool(biz.documents_verified or user.verified_badge)

    # Verifikatsiyadan o‘tmagan business — yangi hisob + hujjat ogohlantirishi.
    if not docs_ok and age_days is not None and age_days < NEW_ACCOUNT_DAYS:
        reasons.append(
            {
                "key": "new_account",
                "label": labels["new_account"],
                "meta": {"account_age_days": age_days},
            }
        )
        score += 35 if age_days < 7 else 25 if age_days < 14 else 18

    if not docs_ok:
        reasons.append(
            {
                "key": "bad_documents",
                "label": labels["bad_documents"],
                "meta": {
                    "certificates_count": len(certs),
                    "documents_verified": False,
                },
            }
        )
        score += 32 if certs else 24

    blocked_by = await count_blocked_by(redis, user.id)
    if blocked_by >= MANY_BLOCKS_THRESHOLD:
        reasons.append(
            {
                "key": "many_blocks",
                "label": labels["many_blocks"],
                "meta": {"blocked_by_count": blocked_by},
            }
        )
        score += 25 if blocked_by < 6 else 35

    trust_data = trust
    if trust_data is None:
        trust_data = await trust_score_service.compute_trust_score(db, user, biz)
    trust_score = int(trust_data.get("score") or 0)
    complaints = int(biz.complaints_count or 0)
    recent_listings = await _recent_listings_count(db, user.id, days=7)

    suspicious = False
    sus_meta: dict = {}
    if complaints >= HIGH_COMPLAINTS:
        suspicious = True
        sus_meta["complaints_count"] = complaints
        score += 12 + min(18, complaints * 4)
    if trust_score > 0 and trust_score < 40:
        suspicious = True
        sus_meta["trust_score"] = trust_score
        score += 15
    # Yangi akkaunt + birdaniga ko‘p e’lon
    if age_days is not None and age_days < 14 and recent_listings >= 8:
        suspicious = True
        sus_meta["recent_listings"] = recent_listings
        score += 12
    # Bo‘sh profil lekin aktiv savdo da’vosi
    thin_profile = not (biz.description or "").strip() and not (biz.website or "").strip()
    if thin_profile and complaints >= 1:
        suspicious = True
        sus_meta["thin_profile"] = True
        score += 8

    if suspicious:
        # Avoid duplicate if already added
        if not any(r["key"] == "suspicious_activity" for r in reasons):
            reasons.append(
                {
                    "key": "suspicious_activity",
                    "label": labels["suspicious_activity"],
                    "meta": sus_meta,
                }
            )

    score = max(0, min(100, score))
    level = _risk_level(score, len(reasons))
    if level == "none":
        return empty

    generated_by = "rules"
    message = _MESSAGE.get(loc, _MESSAGE["uz"]).get(level, _MESSAGE["uz"]["high"])
    ai_msg = await _openai_message(
        locale=loc,
        level=level,
        reasons=reasons,
        company=biz.company_name or user.full_name or "",
    )
    if ai_msg:
        message = ai_msg
        generated_by = "openai"

    return {
        "risk_level": level,
        "risk_score": score,
        "message": message,
        "reasons": reasons,
        "generated_by": generated_by,
        "show_warning": level in {"high", "medium"},
    }
