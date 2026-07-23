"""Admin console domain logic: analytics, users, chats, restore, purge."""

from __future__ import annotations

import csv
import io
import json
import secrets
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import and_, func, inspect as sa_inspect, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.core.security import hash_password
from app.models.chat import Chat, Message
from app.models.payment import Payment
from app.models.user import (
    AccountRestoreRequest,
    AdminAuditLog,
    AdminUser,
    Subscription,
    User,
)
from app.services.admin_ops import write_audit

RETENTION_DAYS = 365


def _serialize_user_brief(user: User) -> dict[str, Any]:
    plan = "basic"
    insp = sa_inspect(user)
    if "subscription" not in insp.unloaded and user.subscription is not None:
        plan = user.subscription.plan
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "number": user.number,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "deleted_at": user.deleted_at,
        "scheduled_purge_at": user.scheduled_purge_at,
        "created_at": user.created_at,
        "plan": plan,
    }


async def list_users(
    db: AsyncSession,
    *,
    search: str | None = None,
    status: Literal["all", "active", "inactive", "deleted"] = "all",
    plan: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(User).options(selectinload(User.subscription))

    if status == "deleted":
        query = query.where(User.deleted_at.is_not(None))
    elif status == "active":
        query = query.where(User.deleted_at.is_(None), User.is_active.is_(True))
    elif status == "inactive":
        query = query.where(User.deleted_at.is_(None), User.is_active.is_(False))
    else:
        # all — prefer non-deleted first but allow deleted via filter
        pass

    if search:
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(
                User.full_name.ilike(pattern),
                User.email.ilike(pattern),
                User.number.ilike(pattern),
            )
        )

    if plan:
        query = query.join(Subscription, Subscription.user_id == User.id).where(
            Subscription.plan == plan
        )

    count_q = select(func.count()).select_from(query.order_by(None).subquery())
    total = int((await db.execute(count_q)).scalar() or 0)

    result = await db.execute(
        query.order_by(User.id.desc()).offset(params.offset).limit(params.page_size)
    )
    users = list(result.scalars().all())
    return {
        "items": [_serialize_user_brief(u) for u in users],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(users) < total,
    }


async def get_user_detail(db: AsyncSession, user_id: int) -> dict[str, Any]:
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)

    pay_result = await db.execute(
        select(Payment)
        .where(Payment.user_id == user.id)
        .order_by(Payment.id.desc())
        .limit(20)
    )
    payments = [
        {
            "id": p.id,
            "status": p.status,
            "kind": p.kind,
            "amount": f"{p.amount:.2f}",
            "currency": p.currency,
            "plan": p.plan,
            "paid_at": p.paid_at,
            "created_at": p.created_at,
        }
        for p in pay_result.scalars().all()
    ]

    sub = user.subscription
    return {
        **_serialize_user_brief(user),
        "birth_date": user.birth_date,
        "gender": user.gender,
        "country": user.country,
        "deletion_reason": user.deletion_reason,
        "subscription": None
        if sub is None
        else {
            "plan": sub.plan,
            "billing_cycle": sub.billing_cycle,
            "started_at": sub.started_at,
            "expires_at": sub.expires_at,
            "auto_renew": sub.auto_renew,
            "is_active": sub.is_active,
            "source": sub.source,
        },
        "recent_payments": payments,
    }


async def soft_delete_user(
    db: AsyncSession,
    *,
    user: User,
    reason: str | None,
    admin: AdminUser | None = None,
    ip: str | None = None,
) -> dict[str, Any]:
    if user.deleted_at is not None:
        raise AppError(message="Already deleted", error_code="ALREADY_DELETED", status_code=409)

    now = datetime.now(UTC)
    user.deleted_at = now
    user.deletion_reason = (reason or "deleted")[:255]
    user.scheduled_purge_at = now + timedelta(days=RETENTION_DAYS)
    user.is_active = False

    # Revoke refresh tokens
    from app.models.user import RefreshToken

    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    await db.flush()

    await write_audit(
        db,
        admin=admin,
        action="user.soft_delete",
        target_type="user",
        target_id=user.id,
        meta={"reason": reason, "source": "admin" if admin else "self"},
        ip=ip,
    )
    return _serialize_user_brief(user)


async def restore_user(
    db: AsyncSession,
    *,
    user: User,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    if user.deletion_reason == "purged":
        raise AppError(
            message="Retention expired — account purged",
            error_code="PURGE_EXPIRED",
            status_code=410,
        )
    if user.deleted_at is None:
        raise AppError(message="User is not deleted", error_code="NOT_DELETED", status_code=400)

    if user.scheduled_purge_at and user.scheduled_purge_at < datetime.now(UTC):
        raise AppError(
            message="Retention expired — account purged",
            error_code="PURGE_EXPIRED",
            status_code=410,
        )

    user.deleted_at = None
    user.deletion_reason = None
    user.scheduled_purge_at = None
    user.is_active = True
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="user.restore",
        target_type="user",
        target_id=user.id,
        ip=ip,
    )
    return _serialize_user_brief(user)


async def admin_reset_password(
    db: AsyncSession,
    *,
    user: User,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, str]:
    if user.deleted_at is not None:
        raise AppError(
            message="Cannot reset password for deleted account",
            error_code="USER_DELETED",
            status_code=400,
        )
    temp = secrets.token_urlsafe(10)
    user.password_hash = hash_password(temp)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="user.reset_password",
        target_type="user",
        target_id=user.id,
        ip=ip,
    )
    # Returned once to the calling superadmin UI — never logged.
    return {"message": "Temporary password generated", "temp_password": temp}


async def patch_subscription(
    db: AsyncSession,
    *,
    user_id: int,
    plan: str | None,
    billing_cycle: str | None,
    expires_at: datetime | None,
    auto_renew: bool | None,
    is_active: bool | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.services.subscription import _cycle_delta, _ensure_business_profile

    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)

    sub = user.subscription
    if sub is None:
        sub = Subscription(user_id=user.id, plan="basic", is_active=True, source="admin")
        db.add(sub)
        await db.flush()

    if plan is not None:
        if plan not in {"basic", "premium", "business"}:
            raise AppError(message="Invalid plan", error_code="VALIDATION_ERROR", status_code=400)
        sub.plan = plan

    if billing_cycle is not None:
        if billing_cycle not in {"monthly", "yearly"}:
            raise AppError(
                message="Invalid billing_cycle",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        sub.billing_cycle = billing_cycle

    if expires_at is not None:
        sub.expires_at = expires_at
    if auto_renew is not None:
        sub.auto_renew = auto_renew
    if is_active is not None:
        sub.is_active = is_active

    # Granting a paid plan: sensible defaults so mobile status is coherent.
    if sub.plan in {"premium", "business"} and sub.is_active:
        now = datetime.now(UTC)
        if sub.billing_cycle is None:
            sub.billing_cycle = "monthly"
        if sub.expires_at is None or sub.expires_at <= now:
            sub.expires_at = now + _cycle_delta(sub.billing_cycle or "monthly")
        if sub.started_at is None:
            sub.started_at = now
        if auto_renew is None and plan is not None:
            # Admin grants are time-boxed gifts unless explicitly set to renew.
            sub.auto_renew = False
        if sub.plan == "business":
            await _ensure_business_profile(db, user)
    elif sub.plan == "basic":
        sub.billing_cycle = None
        sub.started_at = None
        sub.expires_at = None
        sub.auto_renew = False
        if is_active is None:
            sub.is_active = True

    sub.source = "admin"
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="subscription.patch",
        target_type="user",
        target_id=user_id,
        meta={
            "plan": sub.plan,
            "is_active": sub.is_active,
            "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
            "auto_renew": sub.auto_renew,
        },
        ip=ip,
    )
    return {
        "user_id": user_id,
        "plan": sub.plan,
        "billing_cycle": sub.billing_cycle,
        "expires_at": sub.expires_at,
        "auto_renew": sub.auto_renew,
        "is_active": sub.is_active,
        "source": sub.source,
    }


async def list_subscriptions(
    db: AsyncSession,
    *,
    plan: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = (
        select(Subscription, User)
        .join(User, User.id == Subscription.user_id)
        .where(User.deleted_at.is_(None))
    )
    if plan:
        query = query.where(Subscription.plan == plan)

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = (
        await db.execute(
            query.order_by(Subscription.id.desc()).offset(params.offset).limit(params.page_size)
        )
    ).all()
    items = [
        {
            "user_id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "number": user.number,
            "plan": sub.plan,
            "billing_cycle": sub.billing_cycle,
            "expires_at": sub.expires_at,
            "auto_renew": sub.auto_renew,
            "is_active": sub.is_active,
            "source": sub.source,
        }
        for sub, user in rows
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def analytics_overview(
    db: AsyncSession,
    *,
    date_from: date | None = None,
    date_to: date | None = None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    d_from = datetime.combine(date_from or (now.date() - timedelta(days=30)), datetime.min.time(), tzinfo=UTC)
    d_to = datetime.combine(date_to or now.date(), datetime.max.time(), tzinfo=UTC)

    users_total = int(
        (await db.execute(select(func.count()).select_from(User).where(User.deleted_at.is_(None)))).scalar()
        or 0
    )
    users_deleted = int(
        (await db.execute(select(func.count()).select_from(User).where(User.deleted_at.is_not(None)))).scalar()
        or 0
    )
    users_new = int(
        (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(User.created_at >= d_from, User.created_at <= d_to)
            )
        ).scalar()
        or 0
    )
    subs_active = int(
        (
            await db.execute(
                select(func.count()).select_from(Subscription).where(Subscription.is_active.is_(True))
            )
        ).scalar()
        or 0
    )

    plan_rows = (
        await db.execute(
            select(Subscription.plan, func.count())
            .where(Subscription.is_active.is_(True))
            .group_by(Subscription.plan)
        )
    ).all()
    plans = {str(p): int(c) for p, c in plan_rows}

    revenue = (
        await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status == "succeeded",
                Payment.paid_at.is_not(None),
                Payment.paid_at >= d_from,
                Payment.paid_at <= d_to,
            )
        )
    ).scalar()
    pay_status = (
        await db.execute(
            select(Payment.status, func.count())
            .where(Payment.created_at >= d_from, Payment.created_at <= d_to)
            .group_by(Payment.status)
        )
    ).all()

    chats_total = int((await db.execute(select(func.count()).select_from(Chat))).scalar() or 0)
    messages_total = int((await db.execute(select(func.count()).select_from(Message))).scalar() or 0)

    return {
        "from": d_from.date().isoformat(),
        "to": d_to.date().isoformat(),
        "users_total": users_total,
        "users_deleted": users_deleted,
        "users_new": users_new,
        "subscriptions_active": subs_active,
        "subscriptions_by_plan": plans,
        "revenue": f"{Decimal(revenue or 0):.2f}",
        "payments_by_status": {str(s): int(c) for s, c in pay_status},
        "chats_total": chats_total,
        "messages_total": messages_total,
    }


async def analytics_timeseries(
    db: AsyncSession,
    *,
    metric: Literal["users_new", "revenue", "payments"] = "users_new",
    date_from: date | None = None,
    date_to: date | None = None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    d_from = date_from or (now.date() - timedelta(days=30))
    d_to = date_to or now.date()
    if d_to < d_from:
        raise AppError(message="Invalid date range", error_code="VALIDATION_ERROR", status_code=400)
    if (d_to - d_from).days > 90:
        raise AppError(
            message="Date range max is 90 days",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    start = datetime.combine(d_from, datetime.min.time(), tzinfo=UTC)
    end = datetime.combine(d_to, datetime.max.time(), tzinfo=UTC)

    if metric == "users_new":
        day_col = func.date_trunc("day", User.created_at)
        rows = (
            await db.execute(
                select(day_col.label("day"), func.count())
                .where(User.created_at >= start, User.created_at <= end)
                .group_by(day_col)
                .order_by(day_col)
            )
        ).all()
    elif metric == "revenue":
        day_col = func.date_trunc("day", Payment.paid_at)
        rows = (
            await db.execute(
                select(day_col.label("day"), func.coalesce(func.sum(Payment.amount), 0))
                .where(
                    Payment.status == "succeeded",
                    Payment.paid_at.is_not(None),
                    Payment.paid_at >= start,
                    Payment.paid_at <= end,
                )
                .group_by(day_col)
                .order_by(day_col)
            )
        ).all()
    else:
        day_col = func.date_trunc("day", Payment.created_at)
        rows = (
            await db.execute(
                select(day_col.label("day"), func.count())
                .where(Payment.created_at >= start, Payment.created_at <= end)
                .group_by(day_col)
                .order_by(day_col)
            )
        ).all()

    by_day = {
        (r[0].date() if hasattr(r[0], "date") else r[0]).isoformat(): float(r[1] or 0)
        for r in rows
        if r[0] is not None
    }
    points: list[dict[str, Any]] = []
    day = d_from
    while day <= d_to:
        points.append({"date": day.isoformat(), "value": by_day.get(day.isoformat(), 0)})
        day += timedelta(days=1)

    return {"metric": metric, "points": points}


async def list_payments_filtered(
    db: AsyncSession,
    *,
    status: str | None = None,
    kind: str | None = None,
    plan: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(Payment)
    if status:
        query = query.where(Payment.status == status)
    if kind:
        query = query.where(Payment.kind == kind)
    if plan:
        query = query.where(Payment.plan == plan)
    if date_from:
        query = query.where(
            Payment.created_at >= datetime.combine(date_from, datetime.min.time(), tzinfo=UTC)
        )
    if date_to:
        query = query.where(
            Payment.created_at <= datetime.combine(date_to, datetime.max.time(), tzinfo=UTC)
        )

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = (
        await db.execute(
            query.order_by(Payment.id.desc()).offset(params.offset).limit(params.page_size)
        )
    ).scalars().all()
    items = [
        {
            "id": p.id,
            "user_id": p.user_id,
            "status": p.status,
            "provider": p.provider,
            "amount": f"{p.amount:.2f}",
            "currency": p.currency,
            "kind": p.kind,
            "plan": p.plan,
            "billing_cycle": p.billing_cycle,
            "number": p.number,
            "paid_at": p.paid_at,
            "created_at": p.created_at,
        }
        for p in rows
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def payment_stats(
    db: AsyncSession,
    *,
    date_from: date | None = None,
    date_to: date | None = None,
) -> dict[str, Any]:
    overview = await analytics_overview(db, date_from=date_from, date_to=date_to)
    return {
        "revenue": overview["revenue"],
        "payments_by_status": overview["payments_by_status"],
        "from": overview["from"],
        "to": overview["to"],
    }


async def list_chats_for_audit(
    db: AsyncSession,
    *,
    user_id: int | None = None,
    q: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=30, max_size=100)
    query = select(Chat)
    if user_id is not None:
        query = query.where(or_(Chat.user_low_id == user_id, Chat.user_high_id == user_id))

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    chats = list(
        (
            await db.execute(
                query.order_by(Chat.id.desc()).offset(params.offset).limit(params.page_size)
            )
        ).scalars().all()
    )

    items = []
    for chat in chats:
        msg_count = int(
            (
                await db.execute(
                    select(func.count()).select_from(Message).where(Message.chat_id == chat.id)
                )
            ).scalar()
            or 0
        )
        last = (
            await db.execute(
                select(Message)
                .where(Message.chat_id == chat.id)
                .order_by(Message.id.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        preview = None
        if last and last.text_original:
            preview = last.text_original[:120]
        elif q:
            # optional text search filter — skip if no match when q set
            pass
        if q and preview and q.lower() not in preview.lower():
            # still include chat; message search is approximate via last message
            pass
        items.append(
            {
                "id": chat.id,
                "user_low_id": chat.user_low_id,
                "user_high_id": chat.user_high_id,
                "message_count": msg_count,
                "last_message_at": last.created_at if last else chat.last_message_at,
                "last_preview": preview,
                "created_at": chat.created_at,
            }
        )

    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def list_chat_messages_stealth(
    db: AsyncSession,
    *,
    chat_id: int,
    page: int | None = None,
    limit: int | None = None,
    admin: AdminUser,
    ip: str | None = None,
    skip_audit: bool = False,
) -> dict[str, Any]:
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)

    params = normalize_page(page, limit, default_size=100, max_size=200)
    total = int(
        (
            await db.execute(
                select(func.count()).select_from(Message).where(Message.chat_id == chat_id)
            )
        ).scalar()
        or 0
    )
    # Stealth: no MessageRead / WS side effects
    rows = list(
        (
            await db.execute(
                select(Message)
                .where(Message.chat_id == chat_id)
                .order_by(Message.id.asc())
                .offset(params.offset)
                .limit(params.page_size)
            )
        ).scalars().all()
    )
    if not skip_audit:
        await write_audit(
            db,
            admin=admin,
            action="chat.view_messages",
            target_type="chat",
            target_id=chat_id,
            meta={"count": len(rows)},
            ip=ip,
        )
    items = [
        {
            "id": m.id,
            "sender_id": m.sender_id,
            "type": m.type,
            "text_original": m.text_original,
            "original_language": m.original_language,
            "meta": m.meta,
            "is_deleted": m.is_deleted,
            "deleted_for_everyone": m.deleted_for_everyone,
            "created_at": m.created_at,
        }
        for m in rows
    ]
    return {
        "chat_id": chat_id,
        "user_low_id": chat.user_low_id,
        "user_high_id": chat.user_high_id,
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def export_chat(
    db: AsyncSession,
    *,
    chat_id: int,
    fmt: Literal["json", "csv"],
    admin: AdminUser,
    ip: str | None = None,
) -> tuple[str, str, bytes]:
    data = await list_chat_messages_stealth(
        db, chat_id=chat_id, page=1, limit=10000, admin=admin, ip=ip, skip_audit=True
    )
    truncated = bool(data.get("has_more"))
    data["truncated"] = truncated
    data["exported_count"] = len(data.get("items") or [])
    await write_audit(
        db,
        admin=admin,
        action="chat.export",
        target_type="chat",
        target_id=chat_id,
        meta={"format": fmt, "truncated": truncated, "exported_count": data["exported_count"]},
        ip=ip,
    )
    if fmt == "json":
        payload = json.dumps(data, default=str, ensure_ascii=False, indent=2).encode("utf-8")
        return f"chat-{chat_id}.json", "application/json", payload

    buf = io.StringIO()
    writer = csv.DictWriter(
        buf,
        fieldnames=["id", "sender_id", "type", "text_original", "created_at", "is_deleted"],
    )
    writer.writeheader()
    for row in data["items"]:
        writer.writerow(
            {
                "id": row["id"],
                "sender_id": row["sender_id"],
                "type": row["type"],
                "text_original": row.get("text_original") or "",
                "created_at": row["created_at"],
                "is_deleted": row["is_deleted"],
            }
        )
    return f"chat-{chat_id}.csv", "text/csv", buf.getvalue().encode("utf-8")


async def purge_expired_accounts(db: AsyncSession, *, batch_size: int = 500) -> int:
    """Anonymize users past retention — never CASCADE-delete (preserves chats/payments).

    Hard-deleting a User would CASCADE wipe co-participant chats and payment ledger.
    Instead we scrub PII, free email/number for re-registration, keep FK integrity.
    """
    now = datetime.now(UTC)
    total = 0
    while True:
        result = await db.execute(
            select(User)
            .where(
                User.deleted_at.is_not(None),
                User.scheduled_purge_at.is_not(None),
                User.scheduled_purge_at <= now,
                User.deletion_reason.is_distinct_from("purged"),
            )
            .limit(batch_size)
            .with_for_update(skip_locked=True)
        )
        users = list(result.scalars().all())
        if not users:
            break
        for user in users:
            uid = user.id
            # Free unique columns for re-registration while keeping stable tombstone
            user.email = f"purged+{uid}@deleted.invalid"
            user.number = f"P{uid:06d}"[-7:]
            user.full_name = "Deleted User"
            user.password_hash = None
            user.google_sub = None
            user.avatar_url = None
            user.birth_date = None
            user.gender = None
            user.country = None
            user.is_active = False
            user.is_verified = False
            user.verified_badge = False
            user.deletion_reason = "purged"
            user.scheduled_purge_at = None
            # Revoke any leftover tokens
            from app.models.user import RefreshToken

            await db.execute(
                update(RefreshToken)
                .where(RefreshToken.user_id == uid, RefreshToken.revoked_at.is_(None))
                .values(revoked_at=now)
            )
        await db.flush()
        total += len(users)
        if len(users) < batch_size:
            break
    return total


GENERIC_RESTORE_MSG = (
    "If this email belongs to a deleted account, a restore request was recorded. "
    "Support will review eligible requests."
)


async def create_restore_request(
    db: AsyncSession,
    *,
    email: str,
    number: str | None,
    reason: str,
) -> dict[str, Any]:
    """Public restore intake — response must not enumerate accounts."""
    email_n = email.lower().strip()
    user = (
        await db.execute(select(User).where(User.email == email_n))
    ).scalar_one_or_none()

    # Always same shape for callers; only create when eligible
    if user is None or user.deleted_at is None or user.deletion_reason == "purged":
        return {"status": "received", "message": GENERIC_RESTORE_MSG}

    if number and number.strip() and number.strip() != user.number:
        # Wrong number — still generic (no leak)
        return {"status": "received", "message": GENERIC_RESTORE_MSG}

    existing = (
        await db.execute(
            select(AccountRestoreRequest).where(
                AccountRestoreRequest.email == email_n,
                AccountRestoreRequest.status == "pending",
            )
        )
    ).scalar_one_or_none()
    if existing:
        return {"status": "received", "message": GENERIC_RESTORE_MSG, "id": existing.id}

    req = AccountRestoreRequest(
        user_id=user.id,
        email=email_n,
        number=number or user.number,
        reason=reason[:2000],
        status="pending",
    )
    db.add(req)
    await db.flush()
    return {"status": "received", "message": GENERIC_RESTORE_MSG, "id": req.id}


async def list_restore_requests(
    db: AsyncSession,
    *,
    status: str | None = "pending",
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(AccountRestoreRequest)
    if status:
        query = query.where(AccountRestoreRequest.status == status)
    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                query.order_by(AccountRestoreRequest.id.desc())
                .offset(params.offset)
                .limit(params.page_size)
            )
        ).scalars().all()
    )
    return {
        "items": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "email": r.email,
                "number": r.number,
                "reason": r.reason,
                "status": r.status,
                "decision_note": r.decision_note,
                "decided_at": r.decided_at,
                "created_at": r.created_at,
            }
            for r in rows
        ],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total,
    }


async def decide_restore_request(
    db: AsyncSession,
    *,
    request_id: int,
    approve: bool,
    note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    req = (
        await db.execute(
            select(AccountRestoreRequest)
            .where(AccountRestoreRequest.id == request_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if req is None:
        raise AppError(message="Request not found", error_code="NOT_FOUND", status_code=404)
    if req.status != "pending":
        raise AppError(message="Already decided", error_code="ALREADY_PROCESSED", status_code=409)

    req.status = "approved" if approve else "rejected"
    req.decided_by_admin_id = admin.id
    req.decision_note = note
    req.decided_at = datetime.now(UTC)

    if approve and req.user_id:
        user = await db.get(User, req.user_id, with_for_update=True)
        if user is None or user.deletion_reason == "purged":
            raise AppError(
                message="Account already purged — cannot restore",
                error_code="PURGE_EXPIRED",
                status_code=410,
            )
        if user.deleted_at is not None:
            await restore_user(db, user=user, admin=admin, ip=ip)

    await write_audit(
        db,
        admin=admin,
        action="restore.decide",
        target_type="restore_request",
        target_id=request_id,
        meta={"approve": approve},
        ip=ip,
    )
    await db.flush()
    return {"id": req.id, "status": req.status}


async def list_audit_logs(
    db: AsyncSession,
    *,
    action: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(AdminAuditLog)
    if action:
        query = query.where(AdminAuditLog.action == action)
    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                query.order_by(AdminAuditLog.id.desc()).offset(params.offset).limit(params.page_size)
            )
        ).scalars().all()
    )
    return {
        "items": [
            {
                "id": r.id,
                "actor_admin_id": r.actor_admin_id,
                "action": r.action,
                "target_type": r.target_type,
                "target_id": r.target_id,
                "meta": r.meta,
                "ip": r.ip,
                "created_at": r.created_at,
            }
            for r in rows
        ],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total,
    }
