"""Admin user risk scoring — complaints, spam, disposable email, etc."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment import Payment
from app.models.product import Product
from app.models.user import BusinessProfile, User
from app.models.chat import Message

# Common disposable / throwaway providers (lowercase domains).
DISPOSABLE_EMAIL_DOMAINS: frozenset[str] = frozenset(
    {
        "mailinator.com",
        "guerrillamail.com",
        "guerrillamailblock.com",
        "sharklasers.com",
        "grr.la",
        "tempmail.com",
        "temp-mail.org",
        "temp-mail.io",
        "10minutemail.com",
        "10minutemail.net",
        "trashmail.com",
        "yopmail.com",
        "yopmail.fr",
        "discard.email",
        "discardmail.com",
        "getnada.com",
        "maildrop.cc",
        "throwaway.email",
        "fakeinbox.com",
        "mailnesia.com",
        "moakt.com",
        "emailondeck.com",
        "tempr.email",
        "tmpmail.org",
        "tmpmail.net",
        "mailcatch.com",
        "spamgourmet.com",
        "mintemail.com",
        "mytemp.email",
        "inboxkitten.com",
        "mailnull.com",
        "spam4.me",
        "trash-mail.com",
        "getairmail.com",
        "mailtemp.net",
    }
)


def email_domain(email: str | None) -> str:
    if not email or "@" not in email:
        return ""
    return email.rsplit("@", 1)[-1].strip().lower()


def is_disposable_email(email: str | None) -> bool:
    return email_domain(email) in DISPOSABLE_EMAIL_DOMAINS


def risk_level_from_score(score: int) -> str:
    if score >= 60:
        return "high"
    if score >= 35:
        return "medium"
    if score >= 15:
        return "low"
    return "none"


def disposable_email_sql_clause(email_col):
    """SQLAlchemy OR of ilike patterns for disposable domains."""
    from sqlalchemy import or_

    return or_(*[email_col.ilike(f"%@{d}") for d in sorted(DISPOSABLE_EMAIL_DOMAINS)])


async def compute_user_risk(
    db: AsyncSession,
    user: User,
    *,
    complaints: int | None = None,
) -> dict[str, Any]:
    """Compute risk score/flags for a single user (admin 360 / list enrichment)."""
    now = datetime.now(UTC)
    flags: list[str] = []
    score = 0
    reasons: list[str] = []

    if is_disposable_email(user.email):
        score += 35
        flags.append("disposable_email")
        reasons.append("disposable_email")

    if complaints is None:
        complaints = 0
        if user.business is not None:
            complaints = int(user.business.complaints_count or 0)
        else:
            complaints = int(
                (
                    await db.execute(
                        select(func.coalesce(BusinessProfile.complaints_count, 0)).where(
                            BusinessProfile.user_id == user.id
                        )
                    )
                ).scalar()
                or 0
            )

    if complaints >= 1:
        score += min(30, complaints * 10)
        if complaints >= 2:
            flags.append("many_complaints")
        reasons.append(f"complaints:{complaints}")

    rejected = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Product)
                .where(Product.seller_id == user.id, Product.status == "rejected")
            )
        ).scalar()
        or 0
    )
    if rejected:
        score += min(20, rejected * 5)
        if rejected >= 3:
            flags.append("spam_products")
        reasons.append(f"rejected_products:{rejected}")

    failed_since = now - timedelta(days=30)
    failed_pay = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Payment)
                .where(
                    Payment.user_id == user.id,
                    Payment.status.in_(("failed", "canceled", "cancelled")),
                    Payment.created_at >= failed_since,
                )
            )
        ).scalar()
        or 0
    )
    if failed_pay:
        score += min(15, failed_pay * 5)
        if failed_pay >= 3:
            flags.append("payment_abuse")
        reasons.append(f"failed_payments:{failed_pay}")

    day_ago = now - timedelta(hours=24)
    msg_24h = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Message)
                .where(Message.sender_id == user.id, Message.created_at >= day_ago)
            )
        ).scalar()
        or 0
    )
    if msg_24h >= 200:
        score += 20
        flags.append("spam_activity")
        reasons.append(f"messages_24h:{msg_24h}")
    elif msg_24h >= 80:
        score += 10
        flags.append("high_activity")
        reasons.append(f"messages_24h:{msg_24h}")

    created = user.created_at
    if created is not None:
        if created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        age_days = max(0, (now - created).days)
        if age_days < 3 and not user.is_verified:
            score += 10
            flags.append("new_unverified")
            reasons.append("new_unverified")

    score = min(100, score)
    level = risk_level_from_score(score)
    return {
        "risk_score": score,
        "risk_level": level,
        "flags": flags,
        "reasons": reasons,
        "complaints_count": complaints,
        "rejected_products": rejected,
        "failed_payments_30d": failed_pay,
        "messages_24h": msg_24h,
        "disposable_email": is_disposable_email(user.email),
    }


async def compute_user_risk_batch(
    db: AsyncSession,
    users: list[User],
) -> dict[int, dict[str, Any]]:
    """Batch enrichment for list rows (fewer round-trips)."""
    if not users:
        return {}
    ids = [u.id for u in users]
    now = datetime.now(UTC)
    day_ago = now - timedelta(hours=24)
    failed_since = now - timedelta(days=30)

    complaints_map: dict[int, int] = {}
    biz_rows = (
        await db.execute(
            select(BusinessProfile.user_id, BusinessProfile.complaints_count).where(
                BusinessProfile.user_id.in_(ids)
            )
        )
    ).all()
    for uid, c in biz_rows:
        complaints_map[int(uid)] = int(c or 0)

    rejected_map: dict[int, int] = {i: 0 for i in ids}
    rej_rows = (
        await db.execute(
            select(Product.seller_id, func.count())
            .where(Product.seller_id.in_(ids), Product.status == "rejected")
            .group_by(Product.seller_id)
        )
    ).all()
    for sid, c in rej_rows:
        rejected_map[int(sid)] = int(c)

    failed_map: dict[int, int] = {i: 0 for i in ids}
    fail_rows = (
        await db.execute(
            select(Payment.user_id, func.count())
            .where(
                Payment.user_id.in_(ids),
                Payment.status.in_(("failed", "canceled", "cancelled")),
                Payment.created_at >= failed_since,
            )
            .group_by(Payment.user_id)
        )
    ).all()
    for uid, c in fail_rows:
        failed_map[int(uid)] = int(c)

    msg_map: dict[int, int] = {i: 0 for i in ids}
    msg_rows = (
        await db.execute(
            select(Message.sender_id, func.count())
            .where(Message.sender_id.in_(ids), Message.created_at >= day_ago)
            .group_by(Message.sender_id)
        )
    ).all()
    for sid, c in msg_rows:
        msg_map[int(sid)] = int(c)

    out: dict[int, dict[str, Any]] = {}
    for user in users:
        flags: list[str] = []
        reasons: list[str] = []
        score = 0
        complaints = complaints_map.get(user.id, 0)
        rejected = rejected_map.get(user.id, 0)
        failed_pay = failed_map.get(user.id, 0)
        msg_24h = msg_map.get(user.id, 0)

        if is_disposable_email(user.email):
            score += 35
            flags.append("disposable_email")
            reasons.append("disposable_email")
        if complaints >= 1:
            score += min(30, complaints * 10)
            if complaints >= 2:
                flags.append("many_complaints")
            reasons.append(f"complaints:{complaints}")
        if rejected:
            score += min(20, rejected * 5)
            if rejected >= 3:
                flags.append("spam_products")
            reasons.append(f"rejected_products:{rejected}")
        if failed_pay:
            score += min(15, failed_pay * 5)
            if failed_pay >= 3:
                flags.append("payment_abuse")
            reasons.append(f"failed_payments:{failed_pay}")
        if msg_24h >= 200:
            score += 20
            flags.append("spam_activity")
            reasons.append(f"messages_24h:{msg_24h}")
        elif msg_24h >= 80:
            score += 10
            flags.append("high_activity")
            reasons.append(f"messages_24h:{msg_24h}")
        created = user.created_at
        if created is not None:
            if created.tzinfo is None:
                created = created.replace(tzinfo=UTC)
            if max(0, (now - created).days) < 3 and not user.is_verified:
                score += 10
                flags.append("new_unverified")
                reasons.append("new_unverified")

        score = min(100, score)
        out[user.id] = {
            "risk_score": score,
            "risk_level": risk_level_from_score(score),
            "flags": flags,
            "reasons": reasons,
            "complaints_count": complaints,
            "rejected_products": rejected,
            "failed_payments_30d": failed_pay,
            "messages_24h": msg_24h,
            "disposable_email": is_disposable_email(user.email),
        }
    return out
