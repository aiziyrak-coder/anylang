"""Business Trust Score — Alibaba-style multi-factor trust index."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.chat import ChatParticipant, Message
from app.models.user import BusinessProfile, User

_PREMIUM_CERTS = {
    "iso 9001",
    "iso 14001",
    "iso 45001",
    "ce",
    "fda",
    "rohs",
    "gmp",
    "bsci",
    "sedex",
    "got",
    "oeko-tex",
    "halal",
}


def _level(score: int) -> str:
    if score >= 90:
        return "excellent"
    if score >= 75:
        return "good"
    if score >= 55:
        return "fair"
    return "low"


def _score_certificates(certs: list) -> dict:
    items = [str(c or "").strip() for c in (certs or []) if str(c or "").strip()]
    n = len(items)
    if n <= 0:
        base = 0
    elif n == 1:
        base = 8
    elif n == 2:
        base = 12
    elif n == 3:
        base = 15
    else:
        base = 18
    premium = 0
    seen: set[str] = set()
    for c in items:
        key = c.lower()
        if key in seen:
            continue
        seen.add(key)
        if any(p in key for p in _PREMIUM_CERTS):
            premium += 1
    score = min(20, base + min(2, premium))
    return {
        "key": "certificates",
        "score": score,
        "max": 20,
        "count": n,
        "premium_count": min(2, premium),
    }


def _score_response(avg_minutes: float | None, samples: int) -> dict:
    if samples <= 0 or avg_minutes is None:
        # Yangi sotuvchi — neytral baza (ma'lumot yo'q)
        return {
            "key": "response_speed",
            "score": 12,
            "max": 25,
            "avg_minutes": None,
            "samples": 0,
        }
    m = float(avg_minutes)
    if m <= 30:
        score = 25
    elif m <= 120:
        score = 22
    elif m <= 360:
        score = 18
    elif m <= 1440:
        score = 14
    elif m <= 4320:
        score = 8
    else:
        score = 4
    return {
        "key": "response_speed",
        "score": score,
        "max": 25,
        "avg_minutes": round(m, 1),
        "samples": samples,
    }


def _score_complaints(count: int) -> dict:
    n = max(0, int(count or 0))
    score = max(0, 20 - n * 4)
    return {
        "key": "complaints",
        "score": score,
        "max": 20,
        "count": n,
    }


def _score_deals(manual: int, invoices: int) -> dict:
    manual_n = max(0, int(manual or 0))
    inv = max(0, int(invoices or 0))
    # Invoice'lar yumshoq signal (max 10 ta bitim ekvivalenti)
    effective = manual_n + min(inv, 10)
    if effective <= 0:
        score = 6
    elif effective <= 5:
        score = 10
    elif effective <= 20:
        score = 14
    elif effective <= 50:
        score = 17
    else:
        score = 20
    return {
        "key": "successful_deals",
        "score": score,
        "max": 20,
        "count": effective,
        "manual_count": manual_n,
        "invoice_count": inv,
    }


def _score_documents(
    *,
    verified_badge: bool,
    documents_verified: bool,
    factory_verified: bool = False,
    inspection_passed: bool = False,
) -> dict:
    score = 0
    if verified_badge:
        score += 8
    if documents_verified or verified_badge:
        score += 3 if documents_verified else 1
    if factory_verified:
        score += 3
    if inspection_passed:
        score += 1
    score = min(15, score)
    return {
        "key": "verified_documents",
        "score": score,
        "max": 15,
        "verified_badge": bool(verified_badge),
        "documents_verified": bool(documents_verified or verified_badge),
        "factory_verified": bool(factory_verified),
        "inspection_passed": bool(inspection_passed),
    }


async def _avg_reply_minutes(db: AsyncSession, user_id: int) -> tuple[float | None, int]:
    """Peer xabaridan keyingi seller javobi oralig‘i (daqiqa)."""
    since = datetime.now(UTC) - timedelta(days=90)
    chat_ids_result = await db.execute(
        select(ChatParticipant.chat_id).where(ChatParticipant.user_id == user_id)
    )
    chat_ids = [int(r) for r in chat_ids_result.scalars().all()]
    if not chat_ids:
        return None, 0

    # Oxirgi 400 xabar — yetarli sample uchun
    result = await db.execute(
        select(Message.chat_id, Message.sender_id, Message.created_at)
        .where(
            Message.chat_id.in_(chat_ids[:80]),
            Message.created_at >= since,
            Message.is_deleted.is_(False),
        )
        .order_by(Message.chat_id.asc(), Message.created_at.asc())
        .limit(400)
    )
    rows = list(result.all())
    if not rows:
        return None, 0

    latencies: list[float] = []
    pending: dict[int, datetime] = {}
    for chat_id, sender_id, created_at in rows:
        if created_at is None:
            continue
        ts = created_at if created_at.tzinfo else created_at.replace(tzinfo=UTC)
        if sender_id != user_id:
            pending[chat_id] = ts
            continue
        start = pending.pop(chat_id, None)
        if start is None:
            continue
        delta = (ts - start).total_seconds() / 60.0
        if 0.2 <= delta <= 60 * 24 * 14:  # 12s .. 14 kun
            latencies.append(delta)
        if len(latencies) >= 40:
            break

    if not latencies:
        return None, 0
    latencies.sort()
    mid = len(latencies) // 2
    if len(latencies) % 2:
        median = latencies[mid]
    else:
        median = (latencies[mid - 1] + latencies[mid]) / 2
    return median, len(latencies)


async def _invoice_count(db: AsyncSession, user_id: int) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(Message)
        .where(Message.sender_id == user_id, Message.type == "invoice")
    )
    return int(result.scalar() or 0)


async def compute_trust_score(
    db: AsyncSession,
    user: User,
    business: BusinessProfile | None = None,
) -> dict:
    biz = business if business is not None else user.business
    if biz is None:
        return {
            "score": 0,
            "level": "low",
            "breakdown": [],
        }

    avg_min, samples = await _avg_reply_minutes(db, user.id)
    invoices = await _invoice_count(db, user.id)

    parts = [
        _score_certificates(list(biz.certificates or [])),
        _score_response(avg_min, samples),
        _score_complaints(int(biz.complaints_count or 0)),
        _score_deals(int(biz.successful_deals or 0), invoices),
        _score_documents(
            verified_badge=bool(user.verified_badge),
            documents_verified=bool(biz.documents_verified),
            factory_verified=bool(biz.factory_verified),
            inspection_passed=bool(biz.inspection_passed),
        ),
    ]
    total = int(sum(p["score"] for p in parts))
    total = max(0, min(100, total))
    return {
        "score": total,
        "level": _level(total),
        "breakdown": parts,
    }
