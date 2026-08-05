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
from app.models.business_review import BusinessReview
from app.models.chat import Chat, ChatParticipant, Message
from app.models.partner_application import PartnerApplication
from app.models.payment import Payment
from app.models.product import Product
from app.models.user import (
    AccountRestoreRequest,
    AdminAuditLog,
    AdminUser,
    RefreshToken,
    Subscription,
    User,
)
from app.models.verification import BusinessVerificationRequest
from app.services.admin_ops import write_audit

RETENTION_DAYS = 365


async def approx_message_count(db: AsyncSession) -> tuple[int, bool]:
    """Prefer pg_class.reltuples for large tables; fall back to exact COUNT."""
    from sqlalchemy import text

    try:
        result = await db.execute(
            text("SELECT COALESCE(reltuples, 0)::bigint FROM pg_class WHERE relname = 'messages'")
        )
        approx = int(result.scalar() or 0)
        if approx < 10_000:
            exact = int(
                (await db.execute(select(func.count()).select_from(Message))).scalar() or 0
            )
            return exact, False
        return max(approx, 0), True
    except Exception:
        exact = int((await db.execute(select(func.count()).select_from(Message))).scalar() or 0)
        return exact, False


async def exact_message_count(db: AsyncSession) -> int:
    return int((await db.execute(select(func.count()).select_from(Message))).scalar() or 0)


def _serialize_user_brief(user: User) -> dict[str, Any]:
    plan = "basic"
    insp = sa_inspect(user)
    if "subscription" not in insp.unloaded and user.subscription is not None:
        plan = user.subscription.plan
    factory_verified = False
    inspection_passed = False
    audit_report_url = None
    complaints_count = 0
    if "business" not in insp.unloaded and user.business is not None:
        factory_verified = bool(user.business.factory_verified)
        inspection_passed = bool(user.business.inspection_passed)
        audit_report_url = user.business.audit_report_url
        complaints_count = int(user.business.complaints_count or 0)
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "number": user.number,
        "country": user.country,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "factory_verified": factory_verified,
        "inspection_passed": inspection_passed,
        "audit_report_url": audit_report_url,
        "complaints_count": complaints_count,
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
    country: str | None = None,
    verified: str | None = None,
    risk: str | None = None,
    last_active: str | None = None,
    device: str | None = None,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.models.user import BusinessProfile
    from app.services.admin_list import apply_sort, smart_user_search
    from app.services.user_risk import compute_user_risk_batch, disposable_email_sql_clause

    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(User).options(
        selectinload(User.subscription),
        selectinload(User.business),
    )

    if status == "deleted":
        query = query.where(User.deleted_at.is_not(None))
    elif status == "active":
        query = query.where(User.deleted_at.is_(None), User.is_active.is_(True))
    elif status == "inactive":
        query = query.where(User.deleted_at.is_(None), User.is_active.is_(False))

    if search and search.strip():
        query = query.where(
            smart_user_search(
                search,
                number_col=User.number,
                email_col=User.email,
                name_col=User.full_name,
            )
        )

    if plan:
        query = query.join(Subscription, Subscription.user_id == User.id).where(
            Subscription.plan == plan,
            Subscription.is_active.is_(True),
        )

    if country:
        code = country.strip().upper()[:2]
        if code:
            query = query.where(User.country == code)

    if verified in ("yes", "true", "1"):
        query = query.where(User.is_verified.is_(True))
    elif verified in ("no", "false", "0"):
        query = query.where(User.is_verified.is_(False))
    elif verified == "badge":
        query = query.where(User.verified_badge.is_(True))

    now = datetime.now(UTC)
    last_active_sub = (
        select(func.max(func.coalesce(RefreshToken.last_active_at, RefreshToken.created_at)))
        .where(RefreshToken.user_id == User.id, RefreshToken.revoked_at.is_(None))
        .correlate(User)
        .scalar_subquery()
    )
    if last_active == "24h":
        query = query.where(last_active_sub >= now - timedelta(hours=24))
    elif last_active == "7d":
        query = query.where(last_active_sub >= now - timedelta(days=7))
    elif last_active == "30d":
        query = query.where(last_active_sub >= now - timedelta(days=30))
    elif last_active == "inactive_30d":
        query = query.where(
            or_(last_active_sub.is_(None), last_active_sub < now - timedelta(days=30))
        )

    if device:
        d = device.strip().lower()
        device_exists = (
            select(RefreshToken.id)
            .where(
                RefreshToken.user_id == User.id,
                RefreshToken.revoked_at.is_(None),
                or_(
                    RefreshToken.platform.ilike(f"%{d}%"),
                    RefreshToken.device_type.ilike(f"%{d}%"),
                ),
            )
            .exists()
        )
        query = query.where(device_exists)

    if risk and risk not in ("", "all"):
        complaints_sub = (
            select(func.coalesce(BusinessProfile.complaints_count, 0))
            .where(BusinessProfile.user_id == User.id)
            .correlate(User)
            .scalar_subquery()
        )
        rejected_sub = (
            select(func.count())
            .select_from(Product)
            .where(Product.seller_id == User.id, Product.status == "rejected")
            .correlate(User)
            .scalar_subquery()
        )
        failed_sub = (
            select(func.count())
            .select_from(Payment)
            .where(
                Payment.user_id == User.id,
                Payment.status.in_(("failed", "canceled", "cancelled")),
                Payment.created_at >= now - timedelta(days=30),
            )
            .correlate(User)
            .scalar_subquery()
        )
        disposable = disposable_email_sql_clause(User.email)
        high_signal = or_(
            disposable,
            complaints_sub >= 2,
            rejected_sub >= 3,
            failed_sub >= 3,
        )
        any_signal = or_(
            disposable,
            complaints_sub >= 1,
            rejected_sub >= 1,
            failed_sub >= 1,
            and_(User.created_at >= now - timedelta(days=3), User.is_verified.is_(False)),
        )
        if risk == "high":
            query = query.where(high_signal)
        elif risk == "flagged":
            query = query.where(any_signal)
        elif risk == "medium":
            query = query.where(any_signal, ~high_signal)
        elif risk == "low":
            query = query.where(
                and_(User.created_at >= now - timedelta(days=3), User.is_verified.is_(False)),
                ~high_signal,
                complaints_sub < 1,
                rejected_sub < 1,
            )
        elif risk == "none":
            query = query.where(~any_signal)

    count_q = select(func.count()).select_from(query.order_by(None).subquery())
    total = int((await db.execute(count_q)).scalar() or 0)

    order_by = apply_sort(
        {
            "id": User.id,
            "created_at": User.created_at,
            "full_name": User.full_name,
            "number": User.number,
            "email": User.email,
            "country": User.country,
        },
        sort=sort,
        order=order,
        default="id",
    )
    result = await db.execute(
        query.order_by(order_by).offset(params.offset).limit(params.page_size)
    )
    users = list(result.scalars().unique().all())
    risk_map = await compute_user_risk_batch(db, users)

    last_map: dict[int, datetime | None] = {u.id: None for u in users}
    if users:
        la_rows = (
            await db.execute(
                select(
                    RefreshToken.user_id,
                    func.max(func.coalesce(RefreshToken.last_active_at, RefreshToken.created_at)),
                )
                .where(
                    RefreshToken.user_id.in_([u.id for u in users]),
                    RefreshToken.revoked_at.is_(None),
                )
                .group_by(RefreshToken.user_id)
            )
        ).all()
        for uid, ts in la_rows:
            last_map[int(uid)] = ts

    items = []
    for u in users:
        row = _serialize_user_brief(u)
        r = risk_map.get(u.id, {})
        row["risk_score"] = r.get("risk_score", 0)
        row["risk_level"] = r.get("risk_level", "none")
        row["risk_flags"] = r.get("flags", [])
        row["last_active_at"] = last_map.get(u.id)
        items.append(row)

    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(users) < total,
    }


async def get_user_detail(db: AsyncSession, user_id: int) -> dict[str, Any]:
    from app.services.user_risk import compute_user_risk

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

    prod_rows = list(
        (
            await db.execute(
                select(Product)
                .where(Product.seller_id == user.id)
                .order_by(Product.id.desc())
                .limit(20)
            )
        )
        .scalars()
        .all()
    )
    products = [
        {
            "id": p.id,
            "name": p.name,
            "status": p.status,
            "price": f"{p.price:.2f}",
            "currency": p.currency,
            "created_at": p.created_at,
            "moderation_note": p.moderation_note or "",
        }
        for p in prod_rows
    ]

    chat_rows = list(
        (
            await db.execute(
                select(Chat)
                .where(or_(Chat.user_low_id == user.id, Chat.user_high_id == user.id))
                .order_by(func.coalesce(Chat.last_message_at, Chat.created_at).desc())
                .limit(20)
            )
        )
        .scalars()
        .all()
    )
    chats = [
        {
            "id": c.id,
            "type": c.type,
            "title": c.title,
            "message_count": c.message_count,
            "last_message_at": c.last_message_at,
            "peer_id": (
                c.user_high_id
                if c.user_low_id == user.id
                else c.user_low_id
                if c.user_high_id == user.id
                else None
            ),
        }
        for c in chat_rows
    ]

    session_rows = list(
        (
            await db.execute(
                select(RefreshToken)
                .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
                .order_by(
                    func.coalesce(RefreshToken.last_active_at, RefreshToken.created_at).desc()
                )
                .limit(40)
            )
        )
        .scalars()
        .all()
    )
    seen_families: set[str] = set()
    sessions: list[dict[str, Any]] = []
    for s in session_rows:
        if s.family in seen_families:
            continue
        seen_families.add(s.family)
        sessions.append(
            {
                "session_id": s.family,
                "device_id": s.device_id,
                "device_name": s.device_name,
                "device_type": s.device_type,
                "platform": s.platform,
                "app_version": s.app_version,
                "ip_address": s.ip_address,
                "last_active_at": s.last_active_at or s.created_at,
                "session_started_at": s.session_started_at or s.created_at,
            }
        )

    risk = await compute_user_risk(
        db,
        user,
        complaints=int(user.business.complaints_count or 0) if user.business else 0,
    )

    strikes: list[dict[str, Any]] = []
    for p in prod_rows:
        if p.status == "rejected":
            strikes.append(
                {
                    "kind": "product_rejected",
                    "at": p.moderated_at or p.created_at,
                    "label": f"Mahsulot rad etildi: {p.name}",
                    "ref": f"product:{p.id}",
                }
            )
    if risk["complaints_count"]:
        strikes.append(
            {
                "kind": "complaints",
                "at": None,
                "label": f"Shikoyatlar: {risk['complaints_count']}",
                "ref": f"complaints:{risk['complaints_count']}",
            }
        )
    audit_rows = list(
        (
            await db.execute(
                select(AdminAuditLog)
                .where(
                    AdminAuditLog.target_type == "user",
                    AdminAuditLog.target_id == str(user.id),
                    or_(
                        AdminAuditLog.action.ilike("%ban%"),
                        AdminAuditLog.action.ilike("%soft_delete%"),
                        AdminAuditLog.action.ilike("%reject%"),
                        AdminAuditLog.action == "user.patch",
                    ),
                )
                .order_by(AdminAuditLog.created_at.desc())
                .limit(20)
            )
        )
        .scalars()
        .all()
    )
    for log in audit_rows:
        meta = log.meta if isinstance(log.meta, dict) else {}
        if log.action == "user.patch" and meta.get("is_active") is not False:
            continue
        strikes.append(
            {
                "kind": log.action,
                "at": log.created_at,
                "label": log.action,
                "ref": f"audit:{log.id}",
            }
        )

    sub = user.subscription
    brief = _serialize_user_brief(user)
    brief["risk_score"] = risk["risk_score"]
    brief["risk_level"] = risk["risk_level"]
    brief["risk_flags"] = risk["flags"]
    brief["last_active_at"] = sessions[0]["last_active_at"] if sessions else None

    return {
        **brief,
        "birth_date": user.birth_date,
        "gender": user.gender,
        "country": user.country,
        "avatar_url": user.avatar_url,
        "app_language": user.app_language,
        "native_language": user.native_language,
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
        "business": None
        if user.business is None
        else {
            "company_name": user.business.company_name,
            "country": user.business.country,
            "complaints_count": user.business.complaints_count,
            "rating": float(user.business.rating) if user.business.rating is not None else None,
            "documents_verified": user.business.documents_verified,
            "factory_verified": user.business.factory_verified,
            "inspection_passed": user.business.inspection_passed,
        },
        "risk": risk,
        "recent_payments": payments,
        "products": products,
        "chats": chats,
        "sessions": sessions,
        "strikes": strikes[:30],
        "sessions_count": len(sessions),
        "change_timeline": await _user_change_timeline(db, user.id),
    }


async def _user_change_timeline(db: AsyncSession, user_id: int) -> list[dict[str, Any]]:
    from app.services import audit_admin

    return await audit_admin.user_change_timeline(db, user_id=user_id, limit=40)


async def revoke_user_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)

    now = datetime.now(UTC)
    result = await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    revoked = int(result.rowcount or 0)
    try:
        from app.models.push_token import PushToken

        await db.execute(
            update(PushToken)
            .where(PushToken.user_id == user_id, PushToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
    except Exception:
        pass

    await write_audit(
        db,
        admin=admin,
        action="user.revoke_sessions",
        target_type="user",
        target_id=user_id,
        meta={"revoked": revoked},
        ip=ip,
    )
    await db.flush()
    return {"user_id": user_id, "revoked": revoked, "message": "All sessions revoked"}


async def bulk_users(
    db: AsyncSession,
    *,
    user_ids: list[int],
    action: Literal["ban", "unban", "grant_plan"],
    plan: str | None = None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    if not user_ids:
        raise AppError(message="user_ids required", error_code="VALIDATION_ERROR", status_code=400)
    if len(user_ids) > 100:
        raise AppError(message="Max 100 users per bulk", error_code="VALIDATION_ERROR", status_code=400)

    ids = list(dict.fromkeys(user_ids))
    result = await db.execute(select(User).where(User.id.in_(ids), User.deleted_at.is_(None)))
    users = list(result.scalars().all())
    found = {u.id for u in users}
    missing = [i for i in ids if i not in found]
    updated = 0

    if action in ("ban", "unban"):
        active = action == "unban"
        for u in users:
            if u.is_active == active:
                continue
            u.is_active = active
            updated += 1
            if action == "ban":
                await db.execute(
                    update(RefreshToken)
                    .where(RefreshToken.user_id == u.id, RefreshToken.revoked_at.is_(None))
                    .values(revoked_at=datetime.now(UTC))
                )
        await write_audit(
            db,
            admin=admin,
            action=f"user.bulk_{action}",
            target_type="user",
            target_id=",".join(str(i) for i in found),
            meta={"count": updated, "ids": list(found)},
            ip=ip,
        )
    elif action == "grant_plan":
        if plan not in ("basic", "premium", "business"):
            raise AppError(message="Invalid plan", error_code="VALIDATION_ERROR", status_code=400)
        for u in users:
            await patch_subscription(
                db,
                user_id=u.id,
                plan=plan,
                billing_cycle="monthly" if plan != "basic" else None,
                expires_at=(datetime.now(UTC) + timedelta(days=30)) if plan != "basic" else None,
                auto_renew=False,
                is_active=True,
                admin=admin,
                ip=ip,
            )
            updated += 1
        await write_audit(
            db,
            admin=admin,
            action="user.bulk_grant_plan",
            target_type="user",
            target_id=",".join(str(i) for i in found),
            meta={"count": updated, "plan": plan, "ids": list(found)},
            ip=ip,
        )

    await db.flush()
    return {
        "action": action,
        "updated": updated,
        "missing": missing,
        "ids": list(found),
    }


async def export_users_csv(
    db: AsyncSession,
    *,
    search: str | None = None,
    status: Literal["all", "active", "inactive", "deleted"] = "all",
    plan: str | None = None,
    country: str | None = None,
    verified: str | None = None,
    risk: str | None = None,
    last_active: str | None = None,
    device: str | None = None,
    user_ids: list[int] | None = None,
    admin: AdminUser,
    ip: str | None = None,
) -> tuple[str, str, bytes]:
    """Export filtered users (max 5000) as CSV."""
    if user_ids:
        result = await db.execute(
            select(User)
            .where(User.id.in_(user_ids[:500]))
            .options(selectinload(User.subscription), selectinload(User.business))
            .order_by(User.id)
        )
        users = list(result.scalars().unique().all())
    else:
        data = await list_users(
            db,
            search=search,
            status=status,
            plan=plan,
            country=country,
            verified=verified,
            risk=risk,
            last_active=last_active,
            device=device,
            page=1,
            limit=100,
        )
        # Pull more pages up to 5000
        users_brief = list(data["items"])
        page = 2
        while data["has_more"] and len(users_brief) < 5000:
            data = await list_users(
                db,
                search=search,
                status=status,
                plan=plan,
                country=country,
                verified=verified,
                risk=risk,
                last_active=last_active,
                device=device,
                page=page,
                limit=100,
            )
            users_brief.extend(data["items"])
            page += 1
            if page > 50:
                break
        # Re-fetch full rows for CSV consistency when using brief path
        ids = [int(x["id"]) for x in users_brief[:5000]]
        if not ids:
            users = []
        else:
            result = await db.execute(
                select(User)
                .where(User.id.in_(ids))
                .options(selectinload(User.subscription), selectinload(User.business))
                .order_by(User.id)
            )
            users = list(result.scalars().unique().all())

    from app.services.user_risk import compute_user_risk_batch

    risk_map = await compute_user_risk_batch(db, users)
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(
        [
            "id",
            "full_name",
            "email",
            "number",
            "country",
            "plan",
            "is_active",
            "is_verified",
            "verified_badge",
            "risk_score",
            "risk_level",
            "risk_flags",
            "complaints",
            "created_at",
            "deleted_at",
        ]
    )
    for u in users:
        r = risk_map.get(u.id, {})
        plan_name = u.subscription.plan if u.subscription else "basic"
        writer.writerow(
            [
                u.id,
                u.full_name,
                u.email,
                u.number,
                u.country or "",
                plan_name,
                u.is_active,
                u.is_verified,
                u.verified_badge,
                r.get("risk_score", 0),
                r.get("risk_level", "none"),
                "|".join(r.get("flags", [])),
                r.get("complaints_count", 0),
                u.created_at.isoformat() if u.created_at else "",
                u.deleted_at.isoformat() if u.deleted_at else "",
            ]
        )

    await write_audit(
        db,
        admin=admin,
        action="user.export",
        target_type="user",
        target_id="bulk",
        meta={"count": len(users)},
        ip=ip,
    )
    filename = f"users-export-{datetime.now(UTC).strftime('%Y%m%d-%H%M%S')}.csv"
    return filename, "text/csv", buf.getvalue().encode("utf-8-sig")


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
    user.must_change_password = True
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
    churn_reason: str | None = None,
    note: str | None = None,
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

    from_plan = sub.plan

    if plan is not None:
        if plan not in {"basic", "premium", "business"}:
            raise AppError(message="Invalid plan", error_code="VALIDATION_ERROR", status_code=400)
        sub.plan = plan

    if billing_cycle is not None:
        from app.services.subscription import billing_cycle_code, normalize_billing_months

        months = normalize_billing_months(billing_cycle)
        sub.billing_cycle = billing_cycle_code(months)

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
            sub.billing_cycle = "1"
        if sub.expires_at is None or sub.expires_at <= now:
            sub.expires_at = now + _cycle_delta(sub.billing_cycle or "1")
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
    meta: dict[str, Any] = {
        "from_plan": from_plan,
        "to_plan": sub.plan,
        "plan": sub.plan,
        "is_active": sub.is_active,
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
        "auto_renew": sub.auto_renew,
        "source": "admin",
    }
    if churn_reason:
        meta["churn_reason"] = churn_reason[:64]
    if note:
        meta["note"] = note[:500]
    await write_audit(
        db,
        admin=admin,
        action="subscription.patch",
        target_type="user",
        target_id=user_id,
        meta=meta,
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
        "from_plan": from_plan,
    }


async def list_subscriptions(
    db: AsyncSession,
    *,
    plan: str | None = None,
    q: str | None = None,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.services.admin_list import apply_sort, smart_user_search

    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = (
        select(Subscription, User)
        .join(User, User.id == Subscription.user_id)
        .where(User.deleted_at.is_(None))
    )
    if plan:
        query = query.where(Subscription.plan == plan)
    if q and q.strip():
        query = query.where(
            smart_user_search(
                q,
                number_col=User.number,
                email_col=User.email,
                name_col=User.full_name,
            )
        )

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    order_by = apply_sort(
        {
            "id": Subscription.id,
            "plan": Subscription.plan,
            "expires_at": Subscription.expires_at,
            "created_at": Subscription.created_at,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = (
        await db.execute(
            query.order_by(order_by).offset(params.offset).limit(params.page_size)
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
                Payment.status.in_(("succeeded", "paid")),
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
    messages_total, messages_approx = await approx_message_count(db)

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
        "messages_total_approx": messages_approx,
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
                    Payment.status.in_(("succeeded", "paid")),
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


def _pct_change(current: float, previous: float) -> float | None:
    if previous == 0:
        return None if current == 0 else 100.0
    return round((current - previous) / previous * 100.0, 1)


async def _metric_sum(
    db: AsyncSession,
    *,
    metric: Literal["users_new", "revenue", "payments"],
    start: datetime,
    end: datetime,
) -> float:
    if metric == "users_new":
        return float(
            (
                await db.execute(
                    select(func.count())
                    .select_from(User)
                    .where(User.created_at >= start, User.created_at <= end)
                )
            ).scalar()
            or 0
        )
    if metric == "revenue":
        return float(
            (
                await db.execute(
                    select(func.coalesce(func.sum(Payment.amount), 0)).where(
                        Payment.status.in_(("succeeded", "paid")),
                        Payment.paid_at.is_not(None),
                        Payment.paid_at >= start,
                        Payment.paid_at <= end,
                    )
                )
            ).scalar()
            or 0
        )
    return float(
        (
            await db.execute(
                select(func.count())
                .select_from(Payment)
                .where(Payment.created_at >= start, Payment.created_at <= end)
            )
        ).scalar()
        or 0
    )


async def analytics_command_center(
    db: AsyncSession,
    *,
    days: int = 30,
) -> dict[str, Any]:
    """Overview command center: KPIs, geo, attention inbox, trends, ops activity."""
    if days not in (7, 30, 90):
        raise AppError(
            message="days must be 7, 30 or 90",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    now = datetime.now(UTC)
    today_start = datetime.combine(now.date(), datetime.min.time(), tzinfo=UTC)
    day_ago = now - timedelta(hours=24)
    mau_start = now - timedelta(days=30)
    period_end = datetime.combine(now.date(), datetime.max.time(), tzinfo=UTC)
    period_start = datetime.combine(
        (now.date() - timedelta(days=days - 1)), datetime.min.time(), tzinfo=UTC
    )
    prev_end = period_start - timedelta(microseconds=1)
    prev_start = datetime.combine(
        (prev_end.date() - timedelta(days=days - 1)), datetime.min.time(), tzinfo=UTC
    )

    # --- KPIs ---
    dau = int(
        (
            await db.execute(
                select(func.count(func.distinct(RefreshToken.user_id))).where(
                    RefreshToken.revoked_at.is_(None),
                    or_(
                        RefreshToken.last_active_at >= day_ago,
                        and_(
                            RefreshToken.last_active_at.is_(None),
                            RefreshToken.created_at >= day_ago,
                        ),
                    ),
                )
            )
        ).scalar()
        or 0
    )
    mau = int(
        (
            await db.execute(
                select(func.count(func.distinct(RefreshToken.user_id))).where(
                    RefreshToken.revoked_at.is_(None),
                    or_(
                        RefreshToken.last_active_at >= mau_start,
                        and_(
                            RefreshToken.last_active_at.is_(None),
                            RefreshToken.created_at >= mau_start,
                        ),
                    ),
                )
            )
        ).scalar()
        or 0
    )
    users_new = int(
        (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(User.created_at >= period_start, User.created_at <= period_end)
            )
        ).scalar()
        or 0
    )
    users_new_prev = int(
        (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(User.created_at >= prev_start, User.created_at <= prev_end)
            )
        ).scalar()
        or 0
    )
    gmv = (
        await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status.in_(("succeeded", "paid")),
                Payment.paid_at.is_not(None),
                Payment.paid_at >= period_start,
                Payment.paid_at <= period_end,
            )
        )
    ).scalar()
    gmv_prev = (
        await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status.in_(("succeeded", "paid")),
                Payment.paid_at.is_not(None),
                Payment.paid_at >= prev_start,
                Payment.paid_at <= prev_end,
            )
        )
    ).scalar()
    churned = int(
        (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(
                    User.deleted_at.is_not(None),
                    User.deleted_at >= mau_start,
                    User.deleted_at <= now,
                )
            )
        ).scalar()
        or 0
    )
    churn_rate = round((churned / mau) * 100.0, 2) if mau > 0 else 0.0

    users_total = int(
        (await db.execute(select(func.count()).select_from(User).where(User.deleted_at.is_(None)))).scalar()
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

    kpis = {
        "dau": dau,
        "mau": mau,
        "dau_mau_ratio": round((dau / mau) * 100.0, 1) if mau > 0 else 0.0,
        "users_new": users_new,
        "users_new_change_pct": _pct_change(float(users_new), float(users_new_prev)),
        "gmv": f"{Decimal(gmv or 0):.2f}",
        "gmv_change_pct": _pct_change(float(gmv or 0), float(gmv_prev or 0)),
        "churn_rate": churn_rate,
        "churned_users_30d": churned,
        "users_total": users_total,
        "subscriptions_active": subs_active,
    }

    # --- Geography ---
    geo_users_rows = (
        await db.execute(
            select(User.country, func.count())
            .where(User.deleted_at.is_(None), User.country.is_not(None), User.country != "")
            .group_by(User.country)
            .order_by(func.count().desc())
            .limit(40)
        )
    ).all()
    geo_rev_rows = (
        await db.execute(
            select(User.country, func.coalesce(func.sum(Payment.amount), 0))
            .join(Payment, Payment.user_id == User.id)
            .where(
                User.country.is_not(None),
                User.country != "",
                Payment.status.in_(("succeeded", "paid")),
                Payment.paid_at.is_not(None),
                Payment.paid_at >= period_start,
                Payment.paid_at <= period_end,
            )
            .group_by(User.country)
            .order_by(func.coalesce(func.sum(Payment.amount), 0).desc())
            .limit(40)
        )
    ).all()
    rev_by_country = {str(c): float(a or 0) for c, a in geo_rev_rows}
    geo: list[dict[str, Any]] = []
    seen: set[str] = set()
    for country, count in geo_users_rows:
        code = str(country).upper()
        seen.add(code)
        geo.append(
            {
                "country": code,
                "users": int(count),
                "revenue": f"{Decimal(rev_by_country.get(code, 0)):.2f}",
            }
        )
    for code, amount in rev_by_country.items():
        if code.upper() not in seen:
            geo.append({"country": code.upper(), "users": 0, "revenue": f"{Decimal(amount):.2f}"})
    geo.sort(key=lambda x: (-x["users"], -float(x["revenue"])))

    # --- Attention inbox ---
    products_pending = int(
        (
            await db.execute(
                select(func.count()).select_from(Product).where(Product.status == "pending")
            )
        ).scalar()
        or 0
    )
    reviews_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(BusinessReview.status == "pending")
            )
        ).scalar()
        or 0
    )
    verification_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessVerificationRequest)
                .where(BusinessVerificationRequest.status == "pending")
            )
        ).scalar()
        or 0
    )
    applications_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(PartnerApplication.status.in_(("pending", "review")))
            )
        ).scalar()
        or 0
    )
    restore_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(AccountRestoreRequest)
                .where(AccountRestoreRequest.status == "pending")
            )
        ).scalar()
        or 0
    )
    failed_payments = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Payment)
                .where(
                    Payment.status.in_(("failed", "canceled", "cancelled")),
                    Payment.created_at >= mau_start,
                )
            )
        ).scalar()
        or 0
    )

    sla_product = now - timedelta(hours=24)
    sla_review = now - timedelta(hours=48)
    sla_verification = now - timedelta(hours=72)
    products_sla = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Product)
                .where(Product.status == "pending", Product.created_at <= sla_product)
            )
        ).scalar()
        or 0
    )
    reviews_sla = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(BusinessReview.status == "pending", BusinessReview.created_at <= sla_review)
            )
        ).scalar()
        or 0
    )
    verification_sla = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessVerificationRequest)
                .where(
                    BusinessVerificationRequest.status == "pending",
                    BusinessVerificationRequest.submitted_at.is_not(None),
                    BusinessVerificationRequest.submitted_at <= sla_verification,
                )
            )
        ).scalar()
        or 0
    )
    sla_total = products_sla + reviews_sla + verification_sla

    inbox = [
        {
            "id": "products_pending",
            "severity": "moderation",
            "count": products_pending,
            "href": "/dashboard/products",
            "sla_breach": products_sla,
        },
        {
            "id": "reviews_pending",
            "severity": "moderation",
            "count": reviews_pending,
            "href": "/dashboard/reviews",
            "sla_breach": reviews_sla,
        },
        {
            "id": "verification_pending",
            "severity": "moderation",
            "count": verification_pending,
            "href": "/dashboard/verification",
            "sla_breach": verification_sla,
        },
        {
            "id": "applications_pending",
            "severity": "moderation",
            "count": applications_pending,
            "href": "/dashboard/applications",
            "sla_breach": 0,
        },
        {
            "id": "restore_pending",
            "severity": "support",
            "count": restore_pending,
            "href": "/dashboard/restore",
            "sla_breach": 0,
        },
        {
            "id": "failed_payments",
            "severity": "payments",
            "count": failed_payments,
            "href": "/dashboard/payments",
            "sla_breach": 0,
        },
        {
            "id": "sla_breaches",
            "severity": "sla",
            "count": sla_total,
            "href": "/dashboard/products",
            "sla_breach": sla_total,
        },
    ]

    # Fraud signal: failed payments + soft-deletes in 24h (proxy until dedicated fraud queue)
    fraud_deletes_24h = int(
        (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(User.deleted_at.is_not(None), User.deleted_at >= day_ago)
            )
        ).scalar()
        or 0
    )
    failed_24h = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Payment)
                .where(
                    Payment.status.in_(("failed", "canceled", "cancelled")),
                    Payment.created_at >= day_ago,
                )
            )
        ).scalar()
        or 0
    )
    inbox.insert(
        5,
        {
            "id": "fraud_signals",
            "severity": "fraud",
            "count": failed_24h + fraud_deletes_24h,
            "href": "/dashboard/audit",
            "sla_breach": 0,
            "meta": {"failed_payments_24h": failed_24h, "deletes_24h": fraud_deletes_24h},
        },
    )

    # --- Trends (current + previous period % for each metric) ---
    trends: dict[str, Any] = {}
    for metric in ("users_new", "revenue", "payments"):
        series = await analytics_timeseries(
            db,
            metric=metric,  # type: ignore[arg-type]
            date_from=period_start.date(),
            date_to=now.date(),
        )
        current_total = await _metric_sum(
            db, metric=metric, start=period_start, end=period_end  # type: ignore[arg-type]
        )
        previous_total = await _metric_sum(
            db, metric=metric, start=prev_start, end=prev_end  # type: ignore[arg-type]
        )
        trends[metric] = {
            "points": series["points"],
            "total": current_total if metric != "revenue" else round(current_total, 2),
            "previous_total": previous_total if metric != "revenue" else round(previous_total, 2),
            "change_pct": _pct_change(current_total, previous_total),
        }

    # --- Operator activity (today) ---
    decide_actions = (
        "product.moderate.approve",
        "product.moderate.reject",
        "business_review.moderate.approve",
        "business_review.moderate.reject",
        "verification.decide",
        "partner_application.approve",
        "partner_application.reject",
        "product.top_request.approve",
        "product.top_request.reject",
        "restore.approve",
        "restore.reject",
        "restore.decide",
    )
    # Also catch restore decide variants if named differently
    ops_rows = (
        await db.execute(
            select(AdminAuditLog, AdminUser)
            .outerjoin(AdminUser, AdminUser.id == AdminAuditLog.actor_admin_id)
            .where(
                AdminAuditLog.created_at >= today_start,
                or_(
                    AdminAuditLog.action.in_(decide_actions),
                    AdminAuditLog.action.ilike("%.approve"),
                    AdminAuditLog.action.ilike("%.reject"),
                    AdminAuditLog.action.ilike("%moderate%"),
                    AdminAuditLog.action.ilike("%.decide"),
                ),
            )
            .order_by(AdminAuditLog.created_at.desc())
            .limit(50)
        )
    ).all()

    ops_activity: list[dict[str, Any]] = []
    ops_summary: dict[str, dict[str, int]] = {}
    for log, admin in ops_rows:
        actor_name = admin.full_name if admin else "—"
        actor_id = admin.id if admin else None
        action = str(log.action)
        is_reject = "reject" in action.lower() or (
            action.endswith(".decide") and isinstance(log.meta, dict) and log.meta.get("approve") is False
        )
        is_approve = (not is_reject) and (
            "approve" in action.lower()
            or (action.endswith(".decide") and isinstance(log.meta, dict) and log.meta.get("approve") is True)
            or "decide" in action.lower()
        )
        decision = "reject" if is_reject else ("approve" if is_approve else "other")
        key = actor_name
        if key not in ops_summary:
            ops_summary[key] = {"approve": 0, "reject": 0, "other": 0}
        ops_summary[key][decision] = ops_summary[key].get(decision, 0) + 1
        ops_activity.append(
            {
                "id": log.id,
                "at": log.created_at.isoformat() if log.created_at else None,
                "action": action,
                "decision": decision,
                "actor_id": actor_id,
                "actor_name": actor_name,
                "target_type": log.target_type,
                "target_id": log.target_id,
            }
        )

    chats_total = int((await db.execute(select(func.count()).select_from(Chat))).scalar() or 0)
    messages_total, messages_approx = await approx_message_count(db)

    return {
        "generated_at": now.isoformat(),
        "days": days,
        "from": period_start.date().isoformat(),
        "to": now.date().isoformat(),
        "kpis": kpis,
        "geo": geo,
        "inbox": inbox,
        "trends": trends,
        "ops_activity": ops_activity,
        "ops_summary": [
            {"actor_name": name, **counts} for name, counts in sorted(ops_summary.items())
        ],
        "legacy": {
            "chats_total": chats_total,
            "messages_total": messages_total,
            "messages_total_approx": messages_approx,
        },
        "refresh_interval_seconds": 3600,
    }


async def ops_inbox_counts(db: AsyncSession) -> dict[str, Any]:
    """Slim pending counts for nav badges (no heavy KPIs)."""
    now = datetime.now(UTC)
    products_pending = int(
        (
            await db.execute(
                select(func.count()).select_from(Product).where(Product.status == "pending")
            )
        ).scalar()
        or 0
    )
    reviews_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(BusinessReview.status == "pending")
            )
        ).scalar()
        or 0
    )
    verification_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessVerificationRequest)
                .where(BusinessVerificationRequest.status == "pending")
            )
        ).scalar()
        or 0
    )
    applications_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(PartnerApplication.status.in_(("pending", "review")))
            )
        ).scalar()
        or 0
    )
    restore_pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(AccountRestoreRequest)
                .where(AccountRestoreRequest.status == "pending")
            )
        ).scalar()
        or 0
    )
    failed_payments = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Payment)
                .where(Payment.status.in_(("failed", "needs_refund")))
            )
        ).scalar()
        or 0
    )
    items = [
        {
            "id": "products_pending",
            "count": products_pending,
            "href": "/dashboard/products",
        },
        {
            "id": "reviews_pending",
            "count": reviews_pending,
            "href": "/dashboard/reviews",
        },
        {
            "id": "verification_pending",
            "count": verification_pending,
            "href": "/dashboard/verification",
        },
        {
            "id": "applications_pending",
            "count": applications_pending,
            "href": "/dashboard/applications",
        },
        {
            "id": "restore_pending",
            "count": restore_pending,
            "href": "/dashboard/restore",
        },
        {
            "id": "failed_payments",
            "count": failed_payments,
            "href": "/dashboard/payments",
        },
    ]
    return {"items": items, "checked_at": now.isoformat()}


async def list_payments_filtered(
    db: AsyncSession,
    *,
    status: str | None = None,
    kind: str | None = None,
    plan: str | None = None,
    provider: str | None = None,
    q: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.services.admin_list import apply_sort

    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(Payment)
    if status:
        query = query.where(Payment.status == status)
    if kind:
        query = query.where(Payment.kind == kind)
    if plan:
        query = query.where(Payment.plan == plan)
    if provider:
        query = query.where(Payment.provider == provider)
    if q and q.strip():
        term = q.strip()
        if term.isdigit():
            query = query.where(
                or_(Payment.user_id == int(term), Payment.number.ilike(f"{term}%"))
            )
        else:
            pattern = f"%{term}%"
            query = query.where(
                or_(Payment.number.ilike(pattern), Payment.provider.ilike(pattern))
            )
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
    order_by = apply_sort(
        {
            "id": Payment.id,
            "created_at": Payment.created_at,
            "amount": Payment.amount,
            "status": Payment.status,
            "provider": Payment.provider,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = (
        await db.execute(
            query.order_by(order_by).offset(params.offset).limit(params.page_size)
        )
    ).scalars().all()
    items = []
    for p in rows:
        meta = p.meta or {}
        items.append(
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
                "amount_usd": meta.get("amount_usd"),
                "usd_uzs_rate": meta.get("usd_uzs_rate"),
                "refund_reason": p.refund_reason,
                "chargeback_reason": p.chargeback_reason,
                "failed_notified_at": p.failed_notified_at,
            }
        )
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
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.services.admin_list import apply_sort

    params = normalize_page(page, limit, default_size=30, max_size=100)
    query = select(Chat)
    if user_id is not None:
        query = query.where(
            or_(
                Chat.user_low_id == user_id,
                Chat.user_high_id == user_id,
                Chat.id.in_(
                    select(ChatParticipant.chat_id).where(ChatParticipant.user_id == user_id)
                ),
            )
        )

    if q and q.strip():
        term = q.strip()
        if term.isdigit():
            uid = int(term)
            query = query.where(
                or_(
                    Chat.id == uid,
                    Chat.user_low_id == uid,
                    Chat.user_high_id == uid,
                )
            )
        else:
            pattern = f"%{term}%"
            last_msg = (
                select(Message.text_original)
                .where(Message.id == Chat.last_message_id)
                .correlate(Chat)
                .scalar_subquery()
            )
            query = query.where(
                or_(
                    Chat.title.ilike(pattern),
                    last_msg.ilike(pattern),
                )
            )

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    order_by = apply_sort(
        {
            "id": Chat.id,
            "created_at": Chat.created_at,
            "last_message_at": Chat.last_message_at,
            "message_count": Chat.message_count,
        },
        sort=sort,
        order=order,
        default="id",
    )
    chats = list(
        (
            await db.execute(
                query.order_by(order_by).offset(params.offset).limit(params.page_size)
            )
        ).scalars().all()
    )

    # Batch-load last message previews (no N+1 counts — use denorm message_count)
    last_ids = [c.last_message_id for c in chats if c.last_message_id]
    preview_by_id: dict[int, str | None] = {}
    if last_ids:
        rows = (
            await db.execute(select(Message.id, Message.text_original).where(Message.id.in_(last_ids)))
        ).all()
        preview_by_id = {
            mid: (text[:120] if text else None) for mid, text in rows
        }

    items = [
        {
            "id": chat.id,
            "user_low_id": chat.user_low_id,
            "user_high_id": chat.user_high_id,
            "title": chat.title,
            "type": chat.type,
            "message_count": int(getattr(chat, "message_count", 0) or 0),
            "last_message_at": chat.last_message_at,
            "last_preview": preview_by_id.get(chat.last_message_id) if chat.last_message_id else None,
            "created_at": chat.created_at,
        }
        for chat in chats
    ]

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
    cursor: int | None = None,
    limit: int = 500,
) -> tuple[str, str, bytes]:
    """Export chat messages with keyset cursor (avoids broken offset+huge limit)."""
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)

    page_size = max(1, min(limit, 1000))
    query = select(Message).where(Message.chat_id == chat_id)
    if cursor is not None:
        query = query.where(Message.id > cursor)
    rows = list(
        (
            await db.execute(query.order_by(Message.id.asc()).limit(page_size + 1))
        ).scalars().all()
    )
    has_more = len(rows) > page_size
    rows = rows[:page_size]
    next_cursor = rows[-1].id if rows and has_more else None

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
    data: dict[str, Any] = {
        "chat_id": chat_id,
        "user_low_id": chat.user_low_id,
        "user_high_id": chat.user_high_id,
        "items": items,
        "truncated": has_more,
        "exported_count": len(items),
        "next_cursor": next_cursor,
        "has_more": has_more,
    }
    await write_audit(
        db,
        admin=admin,
        action="chat.export",
        target_type="chat",
        target_id=chat_id,
        meta={
            "format": fmt,
            "truncated": has_more,
            "exported_count": len(items),
            "cursor": cursor,
            "next_cursor": next_cursor,
        },
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
    for row in items:
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
    claimed_device_id: str | None = None,
    claimed_device_name: str | None = None,
    keep_chats: bool = True,
) -> dict[str, Any]:
    from app.services import restore_admin

    return await restore_admin.create_restore_request(
        db,
        email=email,
        number=number,
        reason=reason,
        claimed_device_id=claimed_device_id,
        claimed_device_name=claimed_device_name,
        keep_chats=keep_chats,
    )


async def list_restore_requests(
    db: AsyncSession,
    *,
    status: str | None = "pending",
    q: str | None = None,
    sla_only: bool = False,
    risk_only: bool = False,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.services import restore_admin

    return await restore_admin.list_restore_requests(
        db,
        status=status,
        q=q,
        sla_only=sla_only,
        risk_only=risk_only,
        page=page,
        limit=limit,
        sort=sort,
        order=order,
    )


async def decide_restore_request(
    db: AsyncSession,
    *,
    request_id: int,
    approve: bool,
    note: str | None,
    admin: AdminUser,
    keep_chats: bool | None = None,
    require_identity: bool = True,
    notify: bool = True,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.services import restore_admin

    return await restore_admin.decide_restore_request(
        db,
        request_id=request_id,
        approve=approve,
        note=note,
        admin=admin,
        keep_chats=keep_chats,
        require_identity=require_identity,
        notify=notify,
        ip=ip,
    )


async def list_audit_logs(
    db: AsyncSession,
    *,
    action: str | None = None,
    actor_admin_id: int | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    from app.services import audit_admin

    return await audit_admin.list_audit_logs(
        db,
        action=action,
        actor_admin_id=actor_admin_id,
        target_type=target_type,
        target_id=target_id,
        ip=ip,
        date_from=date_from,
        date_to=date_to,
        page=page,
        limit=limit,
        sort=sort,
        order=order,
    )
