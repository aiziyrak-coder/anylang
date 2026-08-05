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
    AnyAdminRole,
    FinancePlus,
    ModeratorPlus,
    SupportOrModerator,
    SupportPlus,
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
    churn_reason: str | None = Field(default=None, max_length=64)
    note: str | None = Field(default=None, max_length=500)


class PlanSettingIn(BaseModel):
    monthly_usd: float | None = None
    trial_days: int | None = Field(default=None, ge=0, le=365)
    limits: dict | None = None
    region_currency: dict | None = None
    features_override: dict | None = None


class SubscriptionPolicyIn(BaseModel):
    grace_days: int | None = Field(default=None, ge=0, le=90)
    soft_lock_enabled: bool | None = None
    reminder_days: list[int] | None = None
    churn_reasons: list[str] | None = None
    soft_lock_message: dict[str, str] | None = None


class RestoreRequestIn(BaseModel):
    email: EmailStr
    number: str | None = Field(default=None, min_length=7, max_length=7)
    reason: str = Field(min_length=5, max_length=2000)
    claimed_device_id: str | None = Field(default=None, max_length=64)
    claimed_device_name: str | None = Field(default=None, max_length=120)
    keep_chats: bool = True


class RestoreDecideIn(BaseModel):
    approve: bool
    note: str | None = None
    keep_chats: bool | None = None
    require_identity: bool = True
    notify: bool = True


class RestorePatchIn(BaseModel):
    email_otp_verified: bool | None = None
    number_verified: bool | None = None
    device_verified: bool | None = None
    risk_impersonation: bool | None = None
    risk_notes: str | None = Field(default=None, max_length=2000)
    keep_chats: bool | None = None
    sla_hours: int | None = Field(default=None, ge=1, le=168)
    claimed_device_id: str | None = Field(default=None, max_length=64)
    claimed_device_name: str | None = Field(default=None, max_length=120)

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


@router.get("/analytics/command-center")
async def analytics_command_center(
    db: DbSession,
    _admin: AnyAdminRole,
    days: int = Query(default=30, description="7 | 30 | 90"),
) -> dict:
    if days not in (7, 30, 90):
        raise AppError(
            message="days must be 7, 30 or 90",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    return await console.analytics_command_center(db, days=days)


@router.get("/inbox")
async def ops_inbox(db: DbSession, admin: AnyAdminRole) -> dict:
    """Lightweight pending counts for nav badges (RBAC-filtered)."""
    data = await console.ops_inbox_counts(db)
    role = admin.role
    items = data.get("items") or []
    if role == "finance":
        items = [i for i in items if i.get("id") in {"failed_payments"}]
    elif role == "support":
        items = [
            i
            for i in items
            if i.get("id") in {"verification_pending", "restore_pending"}
        ]
    elif role == "moderator":
        items = [
            i
            for i in items
            if i.get("id")
            in {
                "products_pending",
                "reviews_pending",
                "verification_pending",
                "applications_pending",
            }
        ]
    # superadmin: all
    return {"items": items, "total_pending": sum(int(i.get("count") or 0) for i in items)}


class BulkUsersIn(BaseModel):
    user_ids: list[int] = Field(min_length=1, max_length=100)
    action: Literal["ban", "unban", "grant_plan"]
    plan: str | None = None


@router.post("/users/bulk")
async def bulk_users(
    body: BulkUsersIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    return await console.bulk_users(
        db,
        user_ids=body.user_ids,
        action=body.action,
        plan=body.plan,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/users/export")
async def export_users(
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
    search: str | None = Query(default=None),
    q: str | None = Query(default=None),
    status_filter: str | None = Query(default="all", alias="status"),
    plan: str | None = Query(default=None),
    country: str | None = Query(default=None),
    verified: str | None = Query(default=None),
    risk: str | None = Query(default=None),
    last_active: str | None = Query(default=None),
    device: str | None = Query(default=None),
    ids: str | None = Query(default=None, description="Comma-separated user ids"),
) -> Response:
    st = status_filter if status_filter in {"all", "active", "inactive", "deleted"} else "all"
    user_ids: list[int] | None = None
    if ids:
        user_ids = []
        for part in ids.split(","):
            part = part.strip()
            if part.isdigit():
                user_ids.append(int(part))
    filename, media, payload = await console.export_users_csv(
        db,
        search=search or q,
        status=st,  # type: ignore[arg-type]
        plan=plan,
        country=country,
        verified=verified,
        risk=risk,
        last_active=last_active,
        device=device,
        user_ids=user_ids,
        admin=admin,
        ip=client_ip(request),
    )
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/users/{user_id}/detail")
async def user_detail(user_id: int, db: DbSession, _admin: SupportOrModerator) -> dict:
    return await console.get_user_detail(db, user_id)


@router.post("/users/{user_id}/revoke-sessions")
async def revoke_user_sessions(
    user_id: int,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    return await console.revoke_user_sessions(
        db, user_id=user_id, admin=admin, ip=client_ip(request)
    )


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
    admin: SupportPlus,
    request: Request,
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="User not found", error_code="USER_NOT_FOUND", status_code=404)
    return await console.restore_user(db, user=user, admin=admin, ip=client_ip(request))


@router.get("/subscriptions")
async def list_subscriptions(
    db: DbSession,
    _admin: FinancePlus,
    plan: str | None = None,
    q: str | None = None,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    return await console.list_subscriptions(
        db, plan=plan, q=q, page=page, limit=limit, sort=sort, order=order
    )


@router.get("/plan-catalog")
async def plan_catalog(
    db: DbSession,
    _admin: ModeratorPlus,
    language: str | None = Query(default="uz_UZ"),
) -> dict:
    """Same catalog the mobile app uses — for admin grant UX (with DB overrides)."""
    from app.services import subscription as subscription_service
    from app.services import subscription_admin as sub_admin

    monthly = await sub_admin.load_monthly_base(db)
    return subscription_service.get_plans(language=language, monthly_base=monthly)


@router.get("/subscriptions/hub")
async def subscriptions_hub(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=90, ge=7, le=365),
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.subscription_hub(db, days=days)


@router.get("/plan-settings")
async def list_plan_settings(db: DbSession, _admin: FinancePlus) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.list_plan_settings(db)


@router.put("/plan-settings/{plan_code}")
async def put_plan_setting(
    plan_code: str,
    body: PlanSettingIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.update_plan_setting(
        db,
        plan_code=plan_code,
        monthly_usd=body.monthly_usd,
        trial_days=body.trial_days,
        limits=body.limits,
        region_currency=body.region_currency,
        features_override=body.features_override,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/subscription-policy")
async def get_subscription_policy(db: DbSession, _admin: FinancePlus) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.get_policy(db)


@router.put("/subscription-policy")
async def put_subscription_policy(
    body: SubscriptionPolicyIn,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.update_policy(
        db,
        grace_days=body.grace_days,
        soft_lock_enabled=body.soft_lock_enabled,
        reminder_days=body.reminder_days,
        churn_reasons=body.churn_reasons,
        soft_lock_message=body.soft_lock_message,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/subscriptions/cohort")
async def subscriptions_cohort(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=90, ge=7, le=365),
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.cohort_analytics(db, days=days)


@router.get("/subscriptions/grants")
async def subscriptions_grants(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=90, ge=7, le=365),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.grant_audit(db, days=days, limit=limit)


@router.get("/subscriptions/reminders")
async def subscriptions_reminders(db: DbSession, _admin: FinancePlus) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.expiry_reminders(db)


@router.get("/subscriptions/ltv")
async def subscriptions_ltv(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=365, ge=30, le=730),
) -> dict:
    from app.services import subscription_admin as sub_admin

    return await sub_admin.ltv_compare(db, days=days)


@router.patch("/subscriptions/{user_id}")
async def patch_subscription(
    user_id: int,
    body: SubscriptionPatchIn,
    db: DbSession,
    admin: FinancePlus,
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
        churn_reason=body.churn_reason,
        note=body.note,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/payments/stats")
async def payments_stats(
    db: DbSession,
    _admin: FinancePlus,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
) -> dict:
    return await console.payment_stats(db, date_from=date_from, date_to=date_to)


@router.get("/payments/hub")
async def payments_hub(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=30, ge=1, le=365),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.payments_hub(db, days=days)


@router.get("/payments/funnel")
async def payments_funnel(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=30, ge=1, le=365),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.provider_funnel(db, days=days)


@router.get("/payments/fx-report")
async def payments_fx_report(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=30, ge=1, le=365),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.fx_report(db, days=days)


@router.get("/payments/suspicious")
async def payments_suspicious(
    db: DbSession,
    _admin: FinancePlus,
    hours: int = Query(default=24, ge=1, le=168),
    min_attempts: int = Query(default=5, ge=2, le=50),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.suspicious_alerts(db, hours=hours, min_attempts=min_attempts)


@router.get("/payments/failed")
async def payments_failed_queue(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=30, ge=1, le=90),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.failed_triage_queue(db, days=days)


@router.get("/payments/refunds")
async def payments_refunds_queue(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=90, ge=1, le=365),
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.refund_chargeback_queue(db, days=days)


class PaymentRefundBody(BaseModel):
    reason: str = Field(default="other", max_length=64)
    note: str | None = Field(default=None, max_length=2000)


class PaymentTriageBody(BaseModel):
    action: Literal["retry", "notify", "dismiss"]
    note: str | None = Field(default=None, max_length=2000)


@router.post("/payments/{payment_id}/refund")
async def payment_refund(
    payment_id: int,
    body: PaymentRefundBody,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.mark_refund(
        db,
        payment_id=payment_id,
        reason=body.reason,
        note=body.note,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/payments/{payment_id}/chargeback")
async def payment_chargeback(
    payment_id: int,
    body: PaymentRefundBody,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.mark_chargeback(
        db,
        payment_id=payment_id,
        reason=body.reason,
        note=body.note,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/payments/{payment_id}/triage")
async def payment_triage(
    payment_id: int,
    body: PaymentTriageBody,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import payments_admin as pay_admin

    return await pay_admin.triage_action(
        db,
        payment_id=payment_id,
        action=body.action,
        note=body.note,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/chats")
async def list_chats(
    db: DbSession,
    admin: SupportPlus,
    request: Request,
    _user_id: int | None = None,
    _q: str | None = None,
    _page: int | None = Query(default=None, ge=1),
    _limit: int | None = Query(default=None, ge=1, le=100),
    _sort: str | None = Query(default=None),
    _order: str | None = Query(default=None),
) -> dict:
    """Full scan disabled — use /chats/search or /chats/cases."""
    await write_audit(
        db,
        admin=admin,
        action="chat.list_blocked",
        ip=client_ip(request),
        meta={"hint": "use_search_or_cases"},
    )
    raise AppError(
        message="To‘liq chat skan o‘chirilgan. Qidiruv yoki case orqali kiring.",
        error_code="CHAT_SCAN_DISABLED",
        status_code=403,
    )


class ChatSearchBody(BaseModel):
    query: str = Field(min_length=3, max_length=200)
    reason: str = Field(min_length=5, max_length=500)


class ChatAccessBody(BaseModel):
    reason: str = Field(min_length=5, max_length=500)
    case_id: int | None = None
    search_query: str | None = Field(default=None, max_length=255)


class ChatCaseCreateBody(BaseModel):
    chat_id: int
    reason: str = Field(default="other", max_length=64)
    description: str = Field(min_length=5, max_length=4000)
    reporter_user_id: int | None = None
    reported_user_id: int | None = None
    source: Literal["report", "search"] = "report"
    search_query: str | None = Field(default=None, max_length=255)


class ChatCaseDecideBody(BaseModel):
    decision: Literal["warn", "ban", "dismiss", "none"]
    decision_note: str | None = Field(default=None, max_length=2000)


class ChatExportBody(BaseModel):
    reason: str = Field(min_length=5, max_length=500)
    format: Literal["json", "csv"] = "json"
    cursor: int | None = Field(default=None, ge=1)
    limit: int = Field(default=500, ge=1, le=1000)


@router.post("/chats/search")
async def chat_search(
    body: ChatSearchBody,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import chat_review as review

    return await review.search_chats(
        db,
        query=body.query,
        reason=body.reason,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/chats/cases")
async def chat_cases(
    db: DbSession,
    _admin: SupportPlus,
    status: str | None = Query(default="open"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=100),
) -> dict:
    from app.services import chat_review as review

    return await review.list_cases(db, status=status, page=page, limit=limit)


@router.post("/chats/cases")
async def chat_case_create(
    body: ChatCaseCreateBody,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import chat_review as review

    return await review.create_case(
        db,
        chat_id=body.chat_id,
        reason=body.reason,
        description=body.description,
        source=body.source,
        reporter_user_id=body.reporter_user_id,
        reported_user_id=body.reported_user_id,
        search_query=body.search_query,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/chats/cases/{case_id}/decide")
async def chat_case_decide(
    case_id: int,
    body: ChatCaseDecideBody,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import chat_review as review

    return await review.decide_case(
        db,
        case_id=case_id,
        decision=body.decision,
        decision_note=body.decision_note,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/chats/{chat_id}/access")
async def chat_open_access(
    chat_id: int,
    body: ChatAccessBody,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import chat_review as review

    return await review.open_chat_access(
        db,
        chat_id=chat_id,
        case_id=body.case_id,
        reason=body.reason,
        search_query=body.search_query,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/chats/{chat_id}/access")
async def chat_access_status(
    chat_id: int,
    admin: SupportPlus,
) -> dict:
    from app.services import chat_review as review

    access = await review.get_access(admin.id, chat_id)
    if access is None:
        return {"active": False, "remaining_seconds": 0}
    return {"active": True, **access}


@router.delete("/chats/{chat_id}/access")
async def chat_close_access(
    chat_id: int,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import chat_review as review

    await review.revoke_access(admin.id, chat_id)
    await write_audit(
        db,
        admin=admin,
        action="chat.access_close",
        target_type="chat",
        target_id=chat_id,
        ip=client_ip(request),
    )
    return {"ok": True}


@router.get("/chats/{chat_id}/messages")
async def chat_messages(
    chat_id: int,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=200),
) -> dict:
    from app.services import chat_review as review

    return await review.list_messages_gated(
        db, chat_id=chat_id, page=page, limit=limit, admin=admin, ip=client_ip(request)
    )


@router.post("/chats/{chat_id}/export")
async def chat_export(
    chat_id: int,
    body: ChatExportBody,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> Response:
    from app.db.redis import get_redis
    from app.services import chat_review as review

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

    filename, media, payload = await review.export_chat_watermarked(
        db,
        chat_id=chat_id,
        fmt=body.format,
        export_reason=body.reason,
        admin=admin,
        ip=client_ip(request),
        cursor=body.cursor,
        limit=body.limit,
    )
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/restore-requests")
async def restore_requests(
    db: DbSession,
    _admin: SupportPlus,
    status: str | None = "pending",
    q: str | None = None,
    sla_only: bool = Query(default=False),
    risk_only: bool = Query(default=False),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    return await console.list_restore_requests(
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


@router.post("/restore-requests")
async def create_restore_request_admin(
    body: RestoreRequestIn,
    db: DbSession,
    _admin: SupportPlus,
) -> dict:
    """Admin can also file a restore request on behalf of a user."""
    return await console.create_restore_request(
        db,
        email=str(body.email),
        number=body.number,
        reason=body.reason,
        claimed_device_id=body.claimed_device_id,
        claimed_device_name=body.claimed_device_name,
        keep_chats=body.keep_chats,
    )


@router.patch("/restore-requests/{request_id}")
async def patch_restore_request(
    request_id: int,
    body: RestorePatchIn,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    from app.services import restore_admin

    data = await restore_admin.patch_restore_request(
        db,
        request_id=request_id,
        admin=admin,
        email_otp_verified=body.email_otp_verified,
        number_verified=body.number_verified,
        device_verified=body.device_verified,
        risk_impersonation=body.risk_impersonation,
        risk_notes=body.risk_notes,
        keep_chats=body.keep_chats,
        sla_hours=body.sla_hours,
        claimed_device_id=body.claimed_device_id,
        claimed_device_name=body.claimed_device_name,
        ip=client_ip(request),
    )
    await db.commit()
    return data


@router.post("/restore-requests/{request_id}/notify")
async def notify_restore_request(
    request_id: int,
    db: DbSession,
    _admin: SupportPlus,
) -> dict:
    from app.services import restore_admin

    data = await restore_admin.notify_restore_status(db, request_id=request_id, force=True)
    await db.commit()
    return data


@router.post("/restore-requests/{request_id}/decide")
async def decide_restore(
    request_id: int,
    body: RestoreDecideIn,
    db: DbSession,
    admin: SupportPlus,
    request: Request,
) -> dict:
    data = await console.decide_restore_request(
        db,
        request_id=request_id,
        approve=body.approve,
        note=body.note,
        admin=admin,
        keep_chats=body.keep_chats,
        require_identity=body.require_identity,
        notify=body.notify,
        ip=client_ip(request),
    )
    await db.commit()
    return data


@router.get("/audit-logs")
async def audit_logs(
    db: DbSession,
    _admin: SuperAdmin,
    action: str | None = None,
    actor_admin_id: int | None = Query(default=None),
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    return await console.list_audit_logs(
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


@router.get("/audit-logs/actors")
async def audit_actors(db: DbSession, _admin: SuperAdmin) -> dict:
    from app.services import audit_admin

    return await audit_admin.list_audit_actors(db)


@router.get("/audit-logs/export")
async def audit_export(
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
    action: str | None = None,
    actor_admin_id: int | None = Query(default=None),
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    fmt: Literal["csv", "json"] = Query(default="csv"),
) -> Response:
    from app.services import audit_admin

    filename, media, payload = await audit_admin.export_audit_logs(
        db,
        admin=admin,
        action=action,
        actor_admin_id=actor_admin_id,
        target_type=target_type,
        target_id=target_id,
        ip=ip,
        date_from=date_from,
        date_to=date_to,
        fmt=fmt,
        ip_addr=client_ip(request),
    )
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/audit-alerts")
async def audit_alerts(
    db: DbSession,
    _admin: SuperAdmin,
    status: str | None = "open",
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    from app.services import audit_admin

    return await audit_admin.list_activity_alerts(
        db, status=status, page=page, limit=limit
    )


@router.post("/audit-alerts/{alert_id}/ack")
async def ack_audit_alert(
    alert_id: int,
    db: DbSession,
    admin: SuperAdmin,
) -> dict:
    from app.services import audit_admin

    data = await audit_admin.ack_activity_alert(db, alert_id=alert_id, admin=admin)
    return data


@router.post("/audit-alerts/scan")
async def scan_audit_alerts(db: DbSession, _admin: SuperAdmin) -> dict:
    from app.services import audit_admin

    created = await audit_admin.scan_anomalous_activity(db)
    return {"created": created}


@router.post("/maintenance/purge-expired/dry-run")
async def purge_expired_dry_run(
    db: DbSession, admin: SuperAdmin, request: Request
) -> dict:
    from app.services import maintenance_ops

    return await maintenance_ops.purge_dry_run(
        db, admin=admin, ip=client_ip(request)
    )


class PurgeConfirmIn(BaseModel):
    confirm_token: str = Field(min_length=10, max_length=128)


@router.post("/maintenance/purge-expired/confirm")
async def purge_expired_confirm(
    body: PurgeConfirmIn,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    from app.services import maintenance_ops

    return await maintenance_ops.purge_confirm(
        db,
        confirm_token=body.confirm_token,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/maintenance/purge-expired")
async def purge_expired(db: DbSession, admin: SuperAdmin, request: Request) -> dict:
    """Legacy: requires dry-run first — redirects clients to controlled flow."""
    raise AppError(
        message="Avval dry-run, keyin confirm_token bilan /purge-expired/confirm chaqiring",
        error_code="PURGE_REQUIRES_CONFIRM",
        status_code=400,
    )


@router.get("/maintenance/health")
async def maintenance_health(_admin: SuperAdmin) -> dict:
    from app.services import maintenance_ops

    return await maintenance_ops.check_system_health()


@router.get("/maintenance/feature-flags")
async def get_feature_flags(db: DbSession, _admin: SuperAdmin) -> dict:
    from app.services import maintenance_ops

    flags = await maintenance_ops.get_feature_flags(db)
    return {"flags": flags}


class FeatureFlagsPatchIn(BaseModel):
    maintenance_mode: bool | None = None
    region_off: list[str] | None = None
    push_enabled: bool | None = None
    translate_enabled: bool | None = None
    payments_enabled: bool | None = None


@router.patch("/maintenance/feature-flags")
async def patch_feature_flags(
    body: FeatureFlagsPatchIn,
    db: DbSession,
    admin: SuperAdmin,
    request: Request,
) -> dict:
    from app.services import maintenance_ops

    patch = {k: v for k, v in body.model_dump().items() if v is not None}
    if not patch:
        raise AppError(
            message="Hech qanday flag yuborilmadi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    flags = await maintenance_ops.update_feature_flags(
        db, patch=patch, admin=admin, ip=client_ip(request)
    )
    return {"flags": flags}


@router.get("/maintenance/job-queues")
async def maintenance_job_queues(db: DbSession, _admin: SuperAdmin) -> dict:
    from app.services import maintenance_ops

    return await maintenance_ops.job_queue_status(db)


@router.get("/maintenance/error-spikes")
async def maintenance_error_spikes(
    db: DbSession,
    _admin: SuperAdmin,
    hours: int = Query(default=24, ge=1, le=168),
) -> dict:
    from app.services import maintenance_ops

    return await maintenance_ops.error_spike_dashboard(db, hours=hours)


@router.get("/maintenance/exact-message-count")
async def exact_message_count(db: DbSession, admin: SuperAdmin, request: Request) -> dict:
    total = await console.exact_message_count(db)
    await write_audit(
        db,
        admin=admin,
        action="maintenance.exact_message_count",
        meta={"messages_total": total},
        ip=client_ip(request),
    )
    return {"messages_total": total, "approx": False}


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
    is_paused: bool = False
    campaign_key: str | None = Field(default=None, max_length=64)
    variant: Literal["A", "B"] | None = None
    code_type: Literal["standard", "campaign", "referral", "influencer"] = "standard"
    segment: Literal["all", "new_users"] = "all"
    new_user_max_age_days: int = Field(default=7, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None
    influencer_label: str | None = Field(default=None, max_length=120)


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
    is_paused: bool | None = None
    campaign_key: str | None = Field(default=None, max_length=64)
    variant: Literal["A", "B"] | None = None
    code_type: Literal["standard", "campaign", "referral", "influencer"] | None = None
    segment: Literal["all", "new_users"] | None = None
    new_user_max_age_days: int | None = Field(default=None, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None
    influencer_label: str | None = Field(default=None, max_length=120)


class PromoCampaignBody(BaseModel):
    campaign_key: str | None = Field(default=None, max_length=64)
    code_a: str = Field(min_length=3, max_length=64)
    code_b: str = Field(min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: Literal["percent", "fixed"] = "percent"
    discount_value_a: float = Field(gt=0)
    discount_value_b: float = Field(gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int = Field(default=1, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    segment: Literal["all", "new_users"] = "all"
    new_user_max_age_days: int = Field(default=7, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None


class PromoPauseBody(BaseModel):
    paused: bool = True


@router.get("/promo-codes")
async def list_promo_codes(
    db: DbSession,
    _admin: FinancePlus,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    q: str | None = None,
    active_only: bool = False,
    code_type: str | None = None,
    campaign_key: str | None = None,
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    from app.services import promo as promo_service

    return await promo_service.list_promos(
        db,
        page=page,
        limit=limit,
        q=q,
        active_only=active_only,
        code_type=code_type,
        campaign_key=campaign_key,
        sort=sort,
        order=order,
    )


@router.get("/promo-codes/dashboard")
async def promo_codes_dashboard(
    db: DbSession,
    _admin: FinancePlus,
    days: int = Query(default=7, ge=1, le=90),
) -> dict:
    from app.services import promo as promo_service

    return await promo_service.promo_dashboard(db, days=days)


@router.post("/promo-codes/campaign")
async def create_promo_campaign(
    body: PromoCampaignBody,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from decimal import Decimal

    from app.services import promo as promo_service

    data = await promo_service.create_ab_campaign(
        db,
        campaign_key=body.campaign_key,
        code_a=body.code_a,
        code_b=body.code_b,
        description=body.description,
        discount_type=body.discount_type,
        discount_value_a=Decimal(str(body.discount_value_a)),
        discount_value_b=Decimal(str(body.discount_value_b)),
        applies_to_plans=body.applies_to_plans,
        min_months=body.min_months,
        max_uses=body.max_uses,
        max_uses_per_user=body.max_uses_per_user,
        valid_from=body.valid_from,
        valid_until=body.valid_until,
        segment=body.segment,
        new_user_max_age_days=body.new_user_max_age_days,
        allowed_countries=body.allowed_countries,
        allowed_languages=body.allowed_languages,
    )
    await write_audit(
        db,
        admin=admin,
        action="promo.campaign_create",
        target_type="promo_campaign",
        target_id=data["campaign_key"],
        meta={"codes": [v["code"] for v in data["variants"]]},
        ip=client_ip(request),
    )
    return data


@router.post("/promo-codes/expire-stale")
async def expire_stale_promo_codes(
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import promo as promo_service

    count = await promo_service.expire_stale_promos(db)
    await write_audit(
        db,
        admin=admin,
        action="promo.expire_stale",
        meta={"expired": count},
        ip=client_ip(request),
    )
    return {"expired": count}


@router.post("/promo-codes")
async def create_promo_code(
    body: PromoCreateBody,
    db: DbSession,
    admin: FinancePlus,
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
        is_paused=body.is_paused,
        campaign_key=body.campaign_key,
        variant=body.variant,
        code_type=body.code_type,
        segment=body.segment,
        new_user_max_age_days=body.new_user_max_age_days,
        allowed_countries=body.allowed_countries,
        allowed_languages=body.allowed_languages,
        influencer_label=body.influencer_label,
    )
    await write_audit(
        db,
        admin=admin,
        action="promo.create",
        target_type="promo_code",
        target_id=data["id"],
        meta={"code": data["code"], "code_type": data["code_type"]},
        ip=client_ip(request),
    )
    return data


@router.patch("/promo-codes/{promo_id}")
async def update_promo_code(
    promo_id: int,
    body: PromoUpdateBody,
    db: DbSession,
    admin: FinancePlus,
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


@router.post("/promo-codes/{promo_id}/pause")
async def pause_promo_code(
    promo_id: int,
    body: PromoPauseBody,
    db: DbSession,
    admin: FinancePlus,
    request: Request,
) -> dict:
    from app.services import promo as promo_service

    data = await promo_service.set_paused(db, promo_id, paused=body.paused)
    await write_audit(
        db,
        admin=admin,
        action="promo.pause" if body.paused else "promo.resume",
        target_type="promo_code",
        target_id=promo_id,
        meta={"code": data["code"], "paused": body.paused},
        ip=client_ip(request),
    )
    return data


@router.delete("/promo-codes/{promo_id}")
async def delete_promo_code(
    promo_id: int,
    db: DbSession,
    admin: FinancePlus,
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

