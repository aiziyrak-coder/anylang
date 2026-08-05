"""Account restore queue — identity checklist, risk, partial restore, SLA."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.integrations.email import send_restore_status_email
from app.models.chat import ChatParticipant
from app.models.user import AccountRestoreRequest, AdminUser, RefreshToken, User
from app.services.admin_list import apply_sort, smart_text_search

GENERIC_RESTORE_MSG = (
    "If this email belongs to a deleted account, a restore request was recorded. "
    "Support will review eligible requests."
)

DEFAULT_SLA_HOURS = 24


def _age_hours(created_at: datetime | None) -> float | None:
    if created_at is None:
        return None
    ts = created_at if created_at.tzinfo else created_at.replace(tzinfo=UTC)
    return max(0.0, (datetime.now(UTC) - ts).total_seconds() / 3600.0)


def _serialize(req: AccountRestoreRequest) -> dict[str, Any]:
    age = _age_hours(req.created_at)
    sla = int(req.sla_hours or DEFAULT_SLA_HOURS)
    return {
        "id": req.id,
        "user_id": req.user_id,
        "email": req.email,
        "number": req.number,
        "reason": req.reason,
        "status": req.status,
        "decision_note": req.decision_note,
        "decided_at": req.decided_at,
        "created_at": req.created_at,
        "email_otp_verified": bool(req.email_otp_verified),
        "number_verified": bool(req.number_verified),
        "device_verified": bool(req.device_verified),
        "claimed_device_id": req.claimed_device_id,
        "claimed_device_name": req.claimed_device_name,
        "risk_impersonation": bool(req.risk_impersonation),
        "risk_notes": req.risk_notes,
        "keep_chats": bool(req.keep_chats),
        "sla_hours": sla,
        "age_hours": round(age, 1) if age is not None else None,
        "sla_breached": bool(age is not None and age >= sla and req.status == "pending"),
        "last_status_notified_at": req.last_status_notified_at,
        "identity_complete": bool(
            req.email_otp_verified and req.number_verified and req.device_verified
        ),
        "identity_meta": dict(req.identity_meta or {}),
    }


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
    """Public restore intake — response must not enumerate accounts."""
    email_n = email.lower().strip()
    user = (await db.execute(select(User).where(User.email == email_n))).scalar_one_or_none()

    if user is None or user.deleted_at is None or user.deletion_reason == "purged":
        return {"status": "received", "message": GENERIC_RESTORE_MSG}

    if number and number.strip() and number.strip() != user.number:
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
        claimed_device_id=(claimed_device_id or "").strip()[:64] or None,
        claimed_device_name=(claimed_device_name or "").strip()[:120] or None,
        keep_chats=bool(keep_chats),
        sla_hours=DEFAULT_SLA_HOURS,
    )
    db.add(req)
    await db.flush()
    return {"status": "received", "message": GENERIC_RESTORE_MSG, "id": req.id}


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
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(AccountRestoreRequest)
    if status:
        query = query.where(AccountRestoreRequest.status == status)
    if risk_only:
        query = query.where(AccountRestoreRequest.risk_impersonation.is_(True))
    if q and q.strip():
        query = query.where(
            smart_text_search(
                q,
                AccountRestoreRequest.email,
                AccountRestoreRequest.number,
                AccountRestoreRequest.reason,
            )
        )
    if sla_only:
        # Pending and older than sla_hours (expression uses created_at + interval via age filter after)
        query = query.where(AccountRestoreRequest.status == "pending")

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    order_by = apply_sort(
        {
            "id": AccountRestoreRequest.id,
            "created_at": AccountRestoreRequest.created_at,
            "status": AccountRestoreRequest.status,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = list(
        (
            await db.execute(
                query.order_by(order_by).offset(params.offset).limit(params.page_size)
            )
        )
        .scalars()
        .all()
    )
    items = [_serialize(r) for r in rows]
    if sla_only:
        items = [i for i in items if i.get("sla_breached")]
        # Approximate: filter after page — for ops queue size is small; recompute total
        total = len(items)

    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total if not sla_only else False,
    }


async def patch_restore_request(
    db: AsyncSession,
    *,
    request_id: int,
    admin: AdminUser,
    email_otp_verified: bool | None = None,
    number_verified: bool | None = None,
    device_verified: bool | None = None,
    risk_impersonation: bool | None = None,
    risk_notes: str | None = None,
    keep_chats: bool | None = None,
    sla_hours: int | None = None,
    claimed_device_id: str | None = None,
    claimed_device_name: str | None = None,
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

    if email_otp_verified is not None:
        req.email_otp_verified = email_otp_verified
    if number_verified is not None:
        req.number_verified = number_verified
    if device_verified is not None:
        req.device_verified = device_verified
    if risk_impersonation is not None:
        req.risk_impersonation = risk_impersonation
    if risk_notes is not None:
        req.risk_notes = risk_notes.strip()[:2000] or None
    if keep_chats is not None:
        req.keep_chats = keep_chats
    if sla_hours is not None:
        req.sla_hours = max(1, min(168, int(sla_hours)))
    if claimed_device_id is not None:
        req.claimed_device_id = claimed_device_id.strip()[:64] or None
    if claimed_device_name is not None:
        req.claimed_device_name = claimed_device_name.strip()[:120] or None

    from app.services.admin_console import write_audit

    await write_audit(
        db,
        admin=admin,
        action="restore.patch",
        target_type="restore_request",
        target_id=request_id,
        meta={
            "email_otp": req.email_otp_verified,
            "number": req.number_verified,
            "device": req.device_verified,
            "risk": req.risk_impersonation,
            "keep_chats": req.keep_chats,
        },
        ip=ip,
    )
    await db.flush()
    return _serialize(req)


async def _strip_user_chats(db: AsyncSession, user_id: int) -> int:
    """Remove user from all chats (messages stay; user no longer participates)."""
    result = await db.execute(
        delete(ChatParticipant).where(ChatParticipant.user_id == user_id)
    )
    return int(result.rowcount or 0)


async def _revoke_sessions(db: AsyncSession, user_id: int) -> int:
    now = datetime.now(UTC)
    result = await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    try:
        from app.models.push_token import PushToken

        await db.execute(
            update(PushToken)
            .where(PushToken.user_id == user_id, PushToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
    except Exception:
        pass
    return int(result.rowcount or 0)


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

    if keep_chats is not None:
        req.keep_chats = keep_chats

    if approve and require_identity:
        if not (req.email_otp_verified and req.number_verified and req.device_verified):
            raise AppError(
                message="Identity checklist incomplete (email OTP, number, device)",
                error_code="IDENTITY_INCOMPLETE",
                status_code=400,
            )

    if approve and req.risk_impersonation and not (note or "").strip():
        raise AppError(
            message="Risk flag set — decision note required",
            error_code="RISK_NOTE_REQUIRED",
            status_code=400,
        )

    req.status = "approved" if approve else "rejected"
    req.decided_by_admin_id = admin.id
    req.decision_note = note
    req.decided_at = datetime.now(UTC)

    chats_removed = 0
    sessions_revoked = 0

    if approve and req.user_id:
        user = await db.get(User, req.user_id, with_for_update=True)
        if user is None or user.deletion_reason == "purged":
            raise AppError(
                message="Account already purged — cannot restore",
                error_code="PURGE_EXPIRED",
                status_code=410,
            )
        if user.deleted_at is not None:
            from app.services.admin_console import restore_user

            await restore_user(db, user=user, admin=admin, ip=ip)

        user.must_change_password = True
        sessions_revoked = await _revoke_sessions(db, user.id)

        if not req.keep_chats:
            chats_removed = await _strip_user_chats(db, user.id)

    from app.services.admin_console import write_audit

    await write_audit(
        db,
        admin=admin,
        action="restore.decide",
        target_type="restore_request",
        target_id=request_id,
        meta={
            "approve": approve,
            "keep_chats": req.keep_chats,
            "risk": req.risk_impersonation,
            "chats_removed": chats_removed,
            "must_change_password": approve,
        },
        ip=ip,
    )
    await db.flush()

    if notify:
        await notify_restore_status(db, request_id=req.id, force=True)

    out = _serialize(req)
    out["chats_removed"] = chats_removed
    out["sessions_revoked"] = sessions_revoked
    return out


async def notify_restore_status(
    db: AsyncSession,
    *,
    request_id: int,
    force: bool = False,
) -> dict[str, Any]:
    req = await db.get(AccountRestoreRequest, request_id)
    if req is None:
        raise AppError(message="Request not found", error_code="NOT_FOUND", status_code=404)

    now = datetime.now(UTC)
    if (
        not force
        and req.last_status_notified_at
        and (now - req.last_status_notified_at).total_seconds() < 3600
    ):
        return {"id": req.id, "notified": False, "reason": "cooldown"}

    user = await db.get(User, req.user_id) if req.user_id else None
    full_name = (user.full_name if user else "") or ""
    lang = (user.app_language if user else None) or "uz_UZ"
    age = _age_hours(req.created_at)
    sla = int(req.sla_hours or DEFAULT_SLA_HOURS)

    await send_restore_status_email(
        to_email=req.email,
        full_name=full_name,
        status=req.status,
        age_hours=age,
        sla_hours=sla,
        keep_chats=bool(req.keep_chats),
        must_change_password=bool(user.must_change_password) if user and req.status == "approved" else False,
        decision_note=req.decision_note,
        app_language=lang,
    )
    req.last_status_notified_at = now
    await db.flush()
    return {"id": req.id, "notified": True, "status": req.status}


async def notify_sla_breaches(db: AsyncSession, *, limit: int = 50) -> int:
    """Send status reminders for pending requests past SLA (or approaching)."""
    rows = list(
        (
            await db.execute(
                select(AccountRestoreRequest)
                .where(AccountRestoreRequest.status == "pending")
                .order_by(AccountRestoreRequest.created_at.asc())
                .limit(limit * 3)
            )
        )
        .scalars()
        .all()
    )
    sent = 0
    now = datetime.now(UTC)
    for req in rows:
        if sent >= limit:
            break
        age = _age_hours(req.created_at)
        sla = int(req.sla_hours or DEFAULT_SLA_HOURS)
        if age is None or age < sla:
            continue
        if req.last_status_notified_at and (now - req.last_status_notified_at) < timedelta(hours=12):
            continue
        result = await notify_restore_status(db, request_id=req.id, force=True)
        if result.get("notified"):
            sent += 1
    return sent
