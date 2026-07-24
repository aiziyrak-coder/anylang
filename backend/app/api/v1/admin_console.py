"""Extended admin console routes — analytics, chats, restore, subscriptions."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from fastapi import APIRouter, Query, Request, Response
from pydantic import BaseModel, EmailStr, Field

from app.core.deps import DbSession
from app.core.errors import AppError
from app.models.user import User
from app.services import admin_console as console
from app.services.admin_ops import (
    ModeratorPlus,
    SuperAdmin,
    client_ip,
    write_audit,
)

router = APIRouter()


class SoftDeleteIn(BaseModel):
    reason: str | None = Field(default=None, max_length=255)


class ResetPasswordOut(BaseModel):
    message: str
    temp_password: str


class SubscriptionPatchIn(BaseModel):
    plan: str | None = None
    billing_cycle: str | None = None
    expires_at: datetime | None = None
    auto_renew: bool | None = None
    is_active: bool | None = None


class RestoreRequestIn(BaseModel):
    email: EmailStr
    number: str | None = Field(default=None, min_length=7, max_length=7)
    reason: str = Field(min_length=5, max_length=2000)


class RestoreDecideIn(BaseModel):
    approve: bool
    note: str | None = None


@router.get("/analytics/overview")
async def analytics_overview(
    db: DbSession,
    _admin: ModeratorPlus,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
) -> dict:
    return await console.analytics_overview(db, date_from=date_from, date_to=date_to)


@router.get("/analytics/timeseries")
async def analytics_timeseries(
    db: DbSession,
    _admin: ModeratorPlus,
    metric: Literal["users_new", "revenue", "payments"] = "users_new",
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
) -> dict:
    return await console.analytics_timeseries(
        db, metric=metric, date_from=date_from, date_to=date_to
    )


@router.get("/users/{user_id}/detail")
async def user_detail(user_id: int, db: DbSession, _admin: ModeratorPlus) -> dict:
    return await console.get_user_detail(db, user_id)


@router.post("/users/{user_id}/reset-password", response_model=ResetPasswordOut)
async def reset_password(
    user_id: int,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> ResetPasswordOut:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)
    data = await console.admin_reset_password(
        db, user=user, admin=admin, ip=client_ip(request)
    )
    return ResetPasswordOut.model_validate(data)


@router.post("/users/{user_id}/soft-delete")
async def soft_delete_user(
    user_id: int,
    body: SoftDeleteIn,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)
    return await console.soft_delete_user(
        db, user=user, reason=body.reason, admin=admin, ip=client_ip(request)
    )


@router.post("/users/{user_id}/restore")
async def restore_user(
    user_id: int,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)
    return await console.restore_user(db, user=user, admin=admin, ip=client_ip(request))


@router.get("/subscriptions")
async def list_subscriptions(
    db: DbSession,
    _admin: ModeratorPlus,
    plan: str | None = None,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    return await console.list_subscriptions(db, plan=plan, page=page, limit=limit)


@router.get("/plan-catalog")
async def plan_catalog(
    _admin: ModeratorPlus,
    language: str | None = Query(default="uz_UZ"),
) -> dict:
    """Same catalog the mobile app uses — for admin grant UX."""
    from app.services import subscription as subscription_service

    return subscription_service.get_plans(language=language)


@router.patch("/subscriptions/{user_id}")
async def patch_subscription(
    user_id: int,
    body: SubscriptionPatchIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    return await console.patch_subscription(
        db,
        user_id=user_id,
        plan=body.plan,
        billing_cycle=body.billing_cycle,
        expires_at=body.expires_at,
        auto_renew=body.auto_renew,
        is_active=body.is_active,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/payments/stats")
async def payments_stats(
    db: DbSession,
    _admin: ModeratorPlus,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
) -> dict:
    return await console.payment_stats(db, date_from=date_from, date_to=date_to)


@router.get("/chats")
async def list_chats(
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
    user_id: int | None = None,
    q: str | None = None,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    await write_audit(
        db,
        admin=admin,
        action="chat.list",
        target_type="user" if user_id else None,
        target_id=user_id,
        ip=client_ip(request),
    )
    return await console.list_chats_for_audit(
        db, user_id=user_id, q=q, page=page, limit=limit
    )


@router.get("/chats/{chat_id}/messages")
async def chat_messages(
    chat_id: int,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=200),
) -> dict:
    return await console.list_chat_messages_stealth(
        db, chat_id=chat_id, page=page, limit=limit, admin=admin, ip=client_ip(request)
    )


@router.get("/chats/{chat_id}/export")
async def chat_export(
    chat_id: int,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
    format: Literal["json", "csv"] = "json",
) -> Response:
    from app.db.redis import get_redis

    redis = await get_redis()
    key = f"admin:export:{admin.id}"
    n = await redis.incr(key)
    if n == 1:
        await redis.expire(key, 3600)
    if n > 30:
        raise AppError(
            message="Export rate limit exceeded (30/hour)",
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
        )

    filename, media, payload = await console.export_chat(
        db, chat_id=chat_id, fmt=format, admin=admin, ip=client_ip(request)
    )
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/restore-requests")
async def restore_requests(
    db: DbSession,
    _admin: SuperAdmin,
    status: str | None = "pending",
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    return await console.list_restore_requests(db, status=status, page=page, limit=limit)


@router.post("/restore-requests")
async def create_restore_request_admin(
    body: RestoreRequestIn,
    db: DbSession,
    _admin: SuperAdmin,
) -> dict:
    """Admin can also file a restore request on behalf of a user."""
    return await console.create_restore_request(
        db, email=str(body.email), number=body.number, reason=body.reason
    )


@router.post("/restore-requests/{request_id}/decide")
async def decide_restore(
    request_id: int,
    body: RestoreDecideIn,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    return await console.decide_restore_request(
        db,
        request_id=request_id,
        approve=body.approve,
        note=body.note,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/audit-logs")
async def audit_logs(
    db: DbSession,
    _admin: SuperAdmin,
    action: str | None = None,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    return await console.list_audit_logs(db, action=action, page=page, limit=limit)


@router.post("/maintenance/purge-expired")
async def purge_expired(db: DbSession, admin: SuperAdmin, request: Request) -> dict:
    count = await console.purge_expired_accounts(db)
    await write_audit(
        db,
        admin=admin,
        action="maintenance.purge",
        meta={"purged": count},
        ip=client_ip(request),
    )
    return {"purged": count}


class PromoCreateBody(BaseModel):
    code: str = Field(min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: Literal["percent", "fixed"] = "percent"
    discount_value: float = Field(gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int = Field(default=1, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool = True


class PromoUpdateBody(BaseModel):
    code: str | None = Field(default=None, min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: Literal["percent", "fixed"] | None = None
    discount_value: float | None = Field(default=None, gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int | None = Field(default=None, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None


@router.get("/promo-codes")
async def list_promo_codes(
    db: DbSession,
    _admin: ModeratorPlus,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    q: str | None = None,
    active_only: bool = False,
) -> dict:
    from app.services import promo as promo_service

    return await promo_service.list_promos(
        db, page=page, limit=limit, q=q, active_only=active_only
    )


@router.post("/promo-codes")
async def create_promo_code(
    body: PromoCreateBody,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from decimal import Decimal

    from app.services import promo as promo_service

    data = await promo_service.create_promo(
        db,
        code=body.code,
        description=body.description,
        discount_type=body.discount_type,
        discount_value=Decimal(str(body.discount_value)),
        applies_to_plans=body.applies_to_plans,
        min_months=body.min_months,
        max_uses=body.max_uses,
        max_uses_per_user=body.max_uses_per_user,
        valid_from=body.valid_from,
        valid_until=body.valid_until,
        is_active=body.is_active,
    )
    await write_audit(
        db,
        admin=admin,
        action="promo.create",
        target_type="promo_code",
        target_id=data["id"],
        meta={"code": data["code"]},
        ip=client_ip(request),
    )
    return data


@router.patch("/promo-codes/{promo_id}")
async def update_promo_code(
    promo_id: int,
    body: PromoUpdateBody,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from decimal import Decimal

    from app.services import promo as promo_service

    payload = body.model_dump(exclude_unset=True)
    if "discount_value" in payload and payload["discount_value"] is not None:
        payload["discount_value"] = Decimal(str(payload["discount_value"]))
    data = await promo_service.update_promo(db, promo_id, **payload)
    await write_audit(
        db,
        admin=admin,
        action="promo.patch",
        target_type="promo_code",
        target_id=promo_id,
        meta={"code": data["code"]},
        ip=client_ip(request),
    )
    return data


@router.delete("/promo-codes/{promo_id}")
async def delete_promo_code(
    promo_id: int,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    from app.services import promo as promo_service

    await promo_service.delete_promo(db, promo_id)
    await write_audit(
        db,
        admin=admin,
        action="promo.delete",
        target_type="promo_code",
        target_id=promo_id,
        ip=client_ip(request),
    )
    return {"ok": True}

