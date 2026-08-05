"""Admin payment ops: funnel, refund/chargeback, failed triage, FX, suspicious."""

from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import AdminUser, User
from app.services.admin_ops import write_audit

REFUND_REASONS = [
    "duplicate",
    "user_request",
    "fulfillment_failed",
    "fraud",
    "other",
]
CHARGEBACK_REASONS = [
    "unauthorized",
    "not_received",
    "duplicate",
    "fraud",
    "other",
]


def _serialize_payment(p: Payment, *, email: str | None = None) -> dict[str, Any]:
    meta = p.meta or {}
    return {
        "id": p.id,
        "user_id": p.user_id,
        "email": email,
        "status": p.status,
        "provider": p.provider,
        "amount": f"{p.amount:.2f}",
        "currency": p.currency,
        "kind": p.kind,
        "plan": p.plan,
        "billing_cycle": p.billing_cycle,
        "number": p.number,
        "paid_at": p.paid_at.isoformat() if p.paid_at else None,
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "amount_usd": meta.get("amount_usd"),
        "usd_uzs_rate": meta.get("usd_uzs_rate"),
        "fx_source": meta.get("fx_source"),
        "fx_date": meta.get("fx_date"),
        "refund_reason": p.refund_reason,
        "refunded_at": p.refunded_at.isoformat() if p.refunded_at else None,
        "chargeback_reason": p.chargeback_reason,
        "chargeback_at": p.chargeback_at.isoformat() if p.chargeback_at else None,
        "triage_note": p.triage_note,
        "failed_notified_at": p.failed_notified_at.isoformat()
        if p.failed_notified_at
        else None,
        "triage_dismissed": bool((meta or {}).get("triage_dismissed")),
    }


async def provider_funnel(db: AsyncSession, *, days: int = 30) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await db.execute(
            select(Payment.provider, Payment.status, func.count())
            .where(Payment.created_at >= since)
            .group_by(Payment.provider, Payment.status)
        )
    ).all()

    by_provider: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for provider, status, cnt in rows:
        by_provider[provider or "unknown"][status or "unknown"] += int(cnt)

    funnel = []
    for provider, statuses in sorted(by_provider.items()):
        total = sum(statuses.values())
        succeeded = statuses.get("succeeded", 0) + statuses.get("refunded", 0)
        # success rate vs terminal-ish attempts (exclude pure pending from denom optional)
        attempts = total
        success_rate = round((succeeded / attempts) * 100.0, 2) if attempts else 0.0
        failed = statuses.get("failed", 0) + statuses.get("cancelled", 0)
        pending = statuses.get("pending", 0)
        funnel.append(
            {
                "provider": provider,
                "total": total,
                "succeeded": statuses.get("succeeded", 0),
                "failed": statuses.get("failed", 0),
                "cancelled": statuses.get("cancelled", 0),
                "pending": pending,
                "refunded": statuses.get("refunded", 0),
                "chargeback": statuses.get("chargeback", 0),
                "needs_refund": statuses.get("needs_refund", 0),
                "success_rate": success_rate,
                "fail_rate": round((failed / attempts) * 100.0, 2) if attempts else 0.0,
                "statuses": dict(statuses),
            }
        )

    return {"days": days, "providers": funnel}


async def fx_report(db: AsyncSession, *, days: int = 30) -> dict[str, Any]:
    from app.payments.fx import ensure_cbu_rate, rate_meta

    since = datetime.now(UTC) - timedelta(days=days)
    await ensure_cbu_rate()
    live = rate_meta()

    rows = (
        await db.execute(
            select(Payment)
            .where(
                Payment.created_at >= since,
                Payment.status.in_(("succeeded", "refunded", "chargeback")),
            )
            .order_by(Payment.created_at.desc())
            .limit(5000)
        )
    ).scalars().all()

    usd_total = Decimal("0")
    uzs_total = Decimal("0")
    by_currency: dict[str, Decimal] = defaultdict(lambda: Decimal("0"))
    by_day: dict[str, dict[str, float]] = defaultdict(
        lambda: {"usd": 0.0, "uzs": 0.0, "count": 0}
    )

    for p in rows:
        meta = p.meta or {}
        cur = (p.currency or "USD").upper()
        by_currency[cur] += Decimal(str(p.amount))
        day = p.created_at.date().isoformat() if p.created_at else "unknown"
        by_day[day]["count"] += 1

        amount_usd = meta.get("amount_usd")
        if amount_usd is not None:
            try:
                usd_val = Decimal(str(amount_usd))
            except Exception:
                usd_val = Decimal("0")
        elif cur == "USD":
            usd_val = Decimal(str(p.amount))
        else:
            # reverse approx if we have rate
            rate_s = meta.get("usd_uzs_rate")
            try:
                rate = Decimal(str(rate_s)) if rate_s else Decimal(str(live["usd_uzs_rate"]))
                usd_val = (Decimal(str(p.amount)) / rate).quantize(Decimal("0.01")) if rate > 0 else Decimal("0")
            except Exception:
                usd_val = Decimal("0")

        usd_total += usd_val
        by_day[day]["usd"] += float(usd_val)

        if cur == "UZS":
            uzs_total += Decimal(str(p.amount))
            by_day[day]["uzs"] += float(p.amount)
        elif meta.get("usd_uzs_rate"):
            try:
                rate = Decimal(str(meta["usd_uzs_rate"]))
                uzs_est = (usd_val * rate).quantize(Decimal("1"))
                uzs_total += uzs_est
                by_day[day]["uzs"] += float(uzs_est)
            except Exception:
                pass

    return {
        "days": days,
        "live_rate": live,
        "succeeded_count": len(rows),
        "usd_total": float(usd_total),
        "uzs_total": float(uzs_total),
        "by_currency": {k: float(v) for k, v in by_currency.items()},
        "daily": [
            {"date": d, **vals}
            for d, vals in sorted(by_day.items(), reverse=True)[:60]
        ],
    }


async def suspicious_alerts(
    db: AsyncSession,
    *,
    hours: int = 24,
    min_attempts: int = 5,
) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(hours=hours)
    rows = (
        await db.execute(
            select(
                Payment.user_id,
                User.email,
                func.count(Payment.id).label("attempts"),
                func.count(Payment.id).filter(Payment.status == "failed").label("failed"),
                func.count(Payment.id).filter(Payment.status == "pending").label("pending"),
                func.count(Payment.id).filter(Payment.status == "succeeded").label("succeeded"),
                func.coalesce(func.sum(Payment.amount), 0).label("amount_sum"),
                func.max(Payment.created_at).label("last_at"),
            )
            .join(User, User.id == Payment.user_id)
            .where(Payment.created_at >= since)
            .group_by(Payment.user_id, User.email)
            .having(func.count(Payment.id) >= min_attempts)
            .order_by(func.count(Payment.id).desc())
            .limit(50)
        )
    ).all()

    alerts = [
        {
            "user_id": uid,
            "email": email,
            "attempts": int(attempts),
            "failed": int(failed or 0),
            "pending": int(pending or 0),
            "succeeded": int(succeeded or 0),
            "amount_sum": float(amount_sum or 0),
            "last_at": last_at.isoformat() if last_at else None,
            "severity": "high" if int(attempts) >= min_attempts * 2 else "medium",
        }
        for uid, email, attempts, failed, pending, succeeded, amount_sum, last_at in rows
    ]
    return {
        "hours": hours,
        "min_attempts": min_attempts,
        "alerts": alerts,
        "count": len(alerts),
    }


async def failed_triage_queue(
    db: AsyncSession,
    *,
    days: int = 30,
    limit: int = 100,
) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await db.execute(
            select(Payment, User)
            .join(User, User.id == Payment.user_id)
            .where(
                Payment.created_at >= since,
                Payment.status.in_(("failed", "cancelled", "needs_refund")),
            )
            .order_by(Payment.created_at.desc())
            .limit(limit)
        )
    ).all()
    items = []
    for p, u in rows:
        if (p.meta or {}).get("triage_dismissed"):
            continue
        items.append(_serialize_payment(p, email=u.email))
    return {"days": days, "items": items, "total": len(items)}


async def refund_chargeback_queue(
    db: AsyncSession,
    *,
    days: int = 90,
    limit: int = 100,
) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await db.execute(
            select(Payment, User)
            .join(User, User.id == Payment.user_id)
            .where(
                or_(
                    Payment.status.in_(("needs_refund", "refunded", "chargeback")),
                    Payment.refunded_at.is_not(None),
                    Payment.chargeback_at.is_not(None),
                ),
                Payment.created_at >= since,
            )
            .order_by(Payment.created_at.desc())
            .limit(limit)
        )
    ).all()
    return {
        "days": days,
        "items": [_serialize_payment(p, email=u.email) for p, u in rows],
        "reason_catalog": {
            "refund": REFUND_REASONS,
            "chargeback": CHARGEBACK_REASONS,
        },
    }


async def mark_refund(
    db: AsyncSession,
    *,
    payment_id: int,
    reason: str,
    note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    payment = await db.get(Payment, payment_id)
    if payment is None:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)
    if payment.status not in {"succeeded", "needs_refund", "pending"}:
        raise AppError(
            message="Bu holatda refund mumkin emas",
            error_code="PAYMENT_INVALID_STATE",
            status_code=400,
        )
    reason_clean = (reason or "other").strip()[:64] or "other"
    payment.status = "refunded"
    payment.refund_reason = reason_clean
    payment.refunded_at = datetime.now(UTC)
    payment.refunded_by_admin_id = admin.id
    if note:
        payment.triage_note = (note or "")[:2000]
    meta = dict(payment.meta or {})
    meta["refund"] = {
        "reason": reason_clean,
        "by_admin_id": admin.id,
        "at": payment.refunded_at.isoformat(),
    }
    payment.meta = meta
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="payment.refund",
        target_type="payment",
        target_id=payment.id,
        meta={"reason": reason_clean, "user_id": payment.user_id},
        ip=ip,
    )
    return _serialize_payment(payment)


async def mark_chargeback(
    db: AsyncSession,
    *,
    payment_id: int,
    reason: str,
    note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    payment = await db.get(Payment, payment_id)
    if payment is None:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)
    if payment.status not in {"succeeded", "refunded", "needs_refund"}:
        raise AppError(
            message="Bu holatda chargeback mumkin emas",
            error_code="PAYMENT_INVALID_STATE",
            status_code=400,
        )
    reason_clean = (reason or "other").strip()[:64] or "other"
    payment.status = "chargeback"
    payment.chargeback_reason = reason_clean
    payment.chargeback_at = datetime.now(UTC)
    if note:
        payment.triage_note = (note or "")[:2000]
    meta = dict(payment.meta or {})
    meta["chargeback"] = {
        "reason": reason_clean,
        "by_admin_id": admin.id,
        "at": payment.chargeback_at.isoformat(),
    }
    payment.meta = meta
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="payment.chargeback",
        target_type="payment",
        target_id=payment.id,
        meta={"reason": reason_clean, "user_id": payment.user_id},
        ip=ip,
    )
    return _serialize_payment(payment)


async def triage_action(
    db: AsyncSession,
    *,
    payment_id: int,
    action: str,
    note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    payment = await db.get(Payment, payment_id)
    if payment is None:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)
    user = await db.get(User, payment.user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)

    action = (action or "").strip().lower()
    if note:
        payment.triage_note = note[:2000]

    result: dict[str, Any] = {"payment_id": payment_id, "action": action}

    if action == "dismiss":
        meta = dict(payment.meta or {})
        meta["triage_dismissed"] = True
        payment.meta = meta
        await db.flush()
        result["ok"] = True

    elif action == "notify":
        from app.integrations.email import send_payment_failed_email

        sent = await send_payment_failed_email(
            to_email=user.email,
            full_name=user.full_name or "",
            payment_id=payment.id,
            amount=f"{payment.amount:.2f}",
            currency=payment.currency,
            kind=payment.kind,
            app_language=getattr(user, "app_language", None) or "uz_UZ",
        )
        payment.failed_notified_at = datetime.now(UTC)
        meta = dict(payment.meta or {})
        meta["failed_notify"] = {
            "sent": bool(sent),
            "at": payment.failed_notified_at.isoformat(),
            "by_admin_id": admin.id,
        }
        payment.meta = meta
        await db.flush()
        result["notified"] = bool(sent)

    elif action == "retry":
        # Mark failed as cancelled and open a fresh checkout for subscription.
        if payment.status not in {"failed", "cancelled", "pending"}:
            raise AppError(
                message="Faqat failed/cancelled uchun retry",
                error_code="PAYMENT_INVALID_STATE",
                status_code=400,
            )
        if payment.kind != "subscription" or not payment.plan:
            raise AppError(
                message="Retry hozircha faqat subscription uchun",
                error_code="PAYMENT_INVALID",
                status_code=400,
            )
        if payment.status == "pending":
            payment.status = "cancelled"
        meta = dict(payment.meta or {})
        meta["retry_requested"] = {
            "at": datetime.now(UTC).isoformat(),
            "by_admin_id": admin.id,
            "from_payment_id": payment.id,
        }
        payment.meta = meta
        await db.flush()

        from app.payments.service import create_subscription_checkout

        checkout = await create_subscription_checkout(
            db,
            user,
            plan=payment.plan,
            billing_cycle=payment.billing_cycle or "1",
            provider=payment.provider or "click",
        )
        result["checkout"] = checkout
        result["ok"] = True

    else:
        raise AppError(message="Noto'g'ri action", error_code="VALIDATION_ERROR", status_code=400)

    await write_audit(
        db,
        admin=admin,
        action=f"payment.triage.{action}",
        target_type="payment",
        target_id=payment.id,
        meta={"user_id": payment.user_id, "note": (note or "")[:200]},
        ip=ip,
    )
    result["payment"] = _serialize_payment(payment, email=user.email)
    return result


async def payments_hub(db: AsyncSession, *, days: int = 30) -> dict[str, Any]:
    funnel = await provider_funnel(db, days=days)
    fx = await fx_report(db, days=days)
    suspicious = await suspicious_alerts(db, hours=24, min_attempts=5)
    failed = await failed_triage_queue(db, days=min(days, 30), limit=40)
    refunds = await refund_chargeback_queue(db, days=max(days, 30), limit=40)
    return {
        "funnel": funnel,
        "fx": fx,
        "suspicious": suspicious,
        "failed": failed,
        "refunds": refunds,
    }
