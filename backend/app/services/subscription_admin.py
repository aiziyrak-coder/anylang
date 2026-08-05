"""Admin subscription ops: plan editor, cohort, grants, grace, LTV."""

from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.payment import Payment
from app.models.plan_settings import PlanCatalogOverride, SubscriptionPolicy
from app.models.user import AdminAuditLog, AdminUser, Subscription, User
from app.services import subscription as sub_svc
from app.services.admin_ops import write_audit

UNSET = object()


async def load_monthly_base(db: AsyncSession) -> dict[str, Decimal | None]:
    """Defaults merged with DB overrides (admin tarif editor)."""
    base = dict(sub_svc.PLAN_MONTHLY_BASE)
    rows = (await db.execute(select(PlanCatalogOverride))).scalars().all()
    for row in rows:
        if row.plan_code in base:
            base[row.plan_code] = row.monthly_usd
    return base


async def get_or_create_policy(db: AsyncSession) -> SubscriptionPolicy:
    pol = await db.get(SubscriptionPolicy, 1)
    if pol is None:
        pol = SubscriptionPolicy(id=1)
        db.add(pol)
        await db.flush()
    return pol


def _override_out(row: PlanCatalogOverride | None, code: str) -> dict[str, Any]:
    defaults = {
        "basic": {
            "monthly_usd": None,
            "trial_days": 0,
            "limits": {"translations_per_day": 20},
            "region_currency": {"default": "USD"},
        },
        "premium": {
            "monthly_usd": "5.00",
            "trial_days": 7,
            "limits": {"translations_per_day": None, "live_mode": True},
            "region_currency": {"default": "USD", "UZ": "UZS"},
        },
        "business": {
            "monthly_usd": "15.00",
            "trial_days": 7,
            "limits": {
                "translations_per_day": None,
                "ai_tools": True,
                "storage_gb": 100,
            },
            "region_currency": {"default": "USD", "UZ": "UZS"},
        },
    }
    d = defaults.get(code, defaults["basic"])
    if row is None:
        return {
            "plan_code": code,
            "monthly_usd": d["monthly_usd"],
            "trial_days": d["trial_days"],
            "limits": d["limits"],
            "region_currency": d["region_currency"],
            "features_override": {},
            "updated_at": None,
            "is_default": True,
        }
    return {
        "plan_code": row.plan_code,
        "monthly_usd": f"{row.monthly_usd:.2f}" if row.monthly_usd is not None else None,
        "trial_days": row.trial_days,
        "limits": dict(row.limits or {}),
        "region_currency": dict(row.region_currency or {"default": "USD"}),
        "features_override": dict(row.features_override or {}),
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
        "is_default": False,
    }


async def list_plan_settings(db: AsyncSession) -> dict[str, Any]:
    rows = {
        r.plan_code: r
        for r in (await db.execute(select(PlanCatalogOverride))).scalars().all()
    }
    plans = [_override_out(rows.get(code), code) for code in ("basic", "premium", "business")]
    return {
        "plans": plans,
        "period_discounts": {str(k): float(v) for k, v in sub_svc.PERIOD_DISCOUNT.items()},
    }


async def update_plan_setting(
    db: AsyncSession,
    *,
    plan_code: str,
    monthly_usd: Any = UNSET,
    trial_days: int | None = None,
    limits: dict | None = None,
    region_currency: dict | None = None,
    features_override: dict | None = None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    if plan_code not in {"basic", "premium", "business"}:
        raise AppError(message="Invalid plan", error_code="VALIDATION_ERROR", status_code=400)

    row = await db.get(PlanCatalogOverride, plan_code)
    if row is None:
        row = PlanCatalogOverride(plan_code=plan_code)
        db.add(row)

    if monthly_usd is not UNSET:
        if plan_code == "basic":
            row.monthly_usd = None
        elif monthly_usd is None or monthly_usd == "":
            row.monthly_usd = None
        else:
            val = Decimal(str(monthly_usd))
            if val < 0:
                raise AppError(
                    message="Price must be >= 0",
                    error_code="VALIDATION_ERROR",
                    status_code=400,
                )
            row.monthly_usd = val.quantize(Decimal("0.01"))

    if trial_days is not None:
        if trial_days < 0 or trial_days > 365:
            raise AppError(
                message="trial_days 0–365",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        row.trial_days = trial_days
    if limits is not None:
        row.limits = limits
    if region_currency is not None:
        row.region_currency = region_currency
    if features_override is not None:
        row.features_override = features_override

    row.updated_at = datetime.now(UTC)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="plan_catalog.update",
        target_type="plan",
        target_id=plan_code,
        meta={
            "monthly_usd": str(row.monthly_usd) if row.monthly_usd is not None else None,
            "trial_days": row.trial_days,
            "limits": row.limits,
            "region_currency": row.region_currency,
        },
        ip=ip,
    )
    return _override_out(row, plan_code)


def _policy_out(pol: SubscriptionPolicy) -> dict[str, Any]:
    return {
        "grace_days": pol.grace_days,
        "soft_lock_enabled": pol.soft_lock_enabled,
        "reminder_days": list(pol.reminder_days or [7, 3, 1]),
        "churn_reasons": list(pol.churn_reasons or []),
        "soft_lock_message": dict(pol.soft_lock_message or {}),
        "updated_at": pol.updated_at.isoformat() if pol.updated_at else None,
    }


async def get_policy(db: AsyncSession) -> dict[str, Any]:
    return _policy_out(await get_or_create_policy(db))


async def update_policy(
    db: AsyncSession,
    *,
    grace_days: int | None = None,
    soft_lock_enabled: bool | None = None,
    reminder_days: list[int] | None = None,
    churn_reasons: list[str] | None = None,
    soft_lock_message: dict | None = None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    pol = await get_or_create_policy(db)
    if grace_days is not None:
        if grace_days < 0 or grace_days > 90:
            raise AppError(
                message="grace_days 0–90",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        pol.grace_days = grace_days
    if soft_lock_enabled is not None:
        pol.soft_lock_enabled = soft_lock_enabled
    if reminder_days is not None:
        cleaned = sorted({int(d) for d in reminder_days if 0 < int(d) <= 90})
        if not cleaned:
            raise AppError(
                message="reminder_days empty",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        pol.reminder_days = cleaned
    if churn_reasons is not None:
        pol.churn_reasons = [str(x).strip()[:64] for x in churn_reasons if str(x).strip()][:20]
    if soft_lock_message is not None:
        pol.soft_lock_message = {str(k)[:8]: str(v)[:500] for k, v in soft_lock_message.items()}
    pol.updated_at = datetime.now(UTC)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="subscription_policy.update",
        target_type="policy",
        target_id="1",
        meta=_policy_out(pol),
        ip=ip,
    )
    return _policy_out(pol)


async def cohort_analytics(db: AsyncSession, *, days: int = 90) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await db.execute(
            select(AdminAuditLog)
            .where(
                AdminAuditLog.action == "subscription.patch",
                AdminAuditLog.created_at >= since,
            )
            .order_by(AdminAuditLog.created_at.desc())
            .limit(5000)
        )
    ).scalars().all()

    transitions: dict[str, int] = defaultdict(int)
    churn_reasons: dict[str, int] = defaultdict(int)
    churn_total = 0
    upgrades = 0
    downgrades = 0

    for log in rows:
        meta = log.meta or {}
        frm = meta.get("from_plan") or meta.get("previous_plan")
        to = meta.get("to_plan") or meta.get("plan")
        if not to:
            continue
        key = f"{frm or '?'}→{to}"
        transitions[key] += 1
        order = sub_svc.PLAN_ORDER
        if frm in order and to in order:
            if order[to] > order[frm]:
                upgrades += 1
            elif order[to] < order[frm]:
                downgrades += 1
                churn_total += 1
                reason = meta.get("churn_reason") or "unspecified"
                churn_reasons[str(reason)] += 1
        elif to == "basic" and frm and frm != "basic":
            churn_total += 1
            reason = meta.get("churn_reason") or "unspecified"
            churn_reasons[str(reason)] += 1

    stock_rows = (
        await db.execute(
            select(Subscription.plan, func.count())
            .where(Subscription.is_active.is_(True))
            .group_by(Subscription.plan)
        )
    ).all()
    stock = {str(p): int(c) for p, c in stock_rows}

    return {
        "days": days,
        "transitions": [
            {"from_to": k, "count": v}
            for k, v in sorted(transitions.items(), key=lambda x: -x[1])
        ],
        "upgrades": upgrades,
        "downgrades": downgrades,
        "churn_total": churn_total,
        "churn_reasons": [
            {"reason": k, "count": v}
            for k, v in sorted(churn_reasons.items(), key=lambda x: -x[1])
        ],
        "active_by_plan": stock,
        "events_sampled": len(rows),
    }


async def grant_audit(
    db: AsyncSession,
    *,
    limit: int = 50,
    days: int = 90,
) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    q = (
        select(AdminAuditLog, AdminUser)
        .outerjoin(AdminUser, AdminUser.id == AdminAuditLog.actor_admin_id)
        .where(
            AdminAuditLog.action == "subscription.patch",
            AdminAuditLog.created_at >= since,
        )
        .order_by(AdminAuditLog.created_at.desc())
        .limit(min(limit, 200))
    )
    rows = (await db.execute(q)).all()
    items = []
    for log, admin in rows:
        meta = log.meta or {}
        items.append(
            {
                "id": log.id,
                "created_at": log.created_at.isoformat() if log.created_at else None,
                "admin_email": admin.email if admin else None,
                "admin_name": admin.full_name if admin else None,
                "user_id": int(log.target_id)
                if log.target_id and str(log.target_id).isdigit()
                else None,
                "from_plan": meta.get("from_plan") or meta.get("previous_plan"),
                "to_plan": meta.get("to_plan") or meta.get("plan"),
                "expires_at": meta.get("expires_at"),
                "churn_reason": meta.get("churn_reason"),
                "note": meta.get("note"),
                "ip": log.ip,
            }
        )
    return {"items": items, "days": days}


async def expiry_reminders(db: AsyncSession) -> dict[str, Any]:
    pol = await get_or_create_policy(db)
    days_list = sorted({int(d) for d in (pol.reminder_days or [7, 3, 1]) if int(d) > 0})
    max_d = max(days_list) if days_list else 7
    now = datetime.now(UTC)
    horizon = now + timedelta(days=max_d)

    rows = (
        await db.execute(
            select(Subscription, User)
            .join(User, User.id == Subscription.user_id)
            .where(
                Subscription.plan.in_(("premium", "business")),
                Subscription.is_active.is_(True),
                Subscription.expires_at.is_not(None),
                Subscription.expires_at >= now,
                Subscription.expires_at <= horizon,
                User.deleted_at.is_(None),
            )
            .order_by(Subscription.expires_at.asc())
            .limit(200)
        )
    ).all()

    buckets: dict[str, list] = {str(d): [] for d in days_list}
    buckets["other"] = []
    items = []
    for sub, user in rows:
        assert sub.expires_at is not None
        left = (sub.expires_at - now).total_seconds() / 86400.0
        days_left = max(0, int(left))
        matched = None
        for d in days_list:
            if days_left <= d:
                matched = d
                break
        bucket_key = str(matched) if matched is not None else "other"
        row = {
            "user_id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "plan": sub.plan,
            "expires_at": sub.expires_at.isoformat(),
            "days_left": days_left,
            "reminder_bucket": matched,
            "auto_renew": sub.auto_renew,
            "source": sub.source,
        }
        buckets.setdefault(bucket_key, []).append(row)
        items.append(row)

    return {
        "reminder_days": days_list,
        "grace_days": pol.grace_days,
        "soft_lock_enabled": pol.soft_lock_enabled,
        "counts": {k: len(v) for k, v in buckets.items()},
        "items": items,
    }


async def ltv_compare(db: AsyncSession, *, days: int = 365) -> dict[str, Any]:
    since = datetime.now(UTC) - timedelta(days=days)
    out: dict[str, Any] = {"days": days, "plans": {}}
    price_base = await load_monthly_base(db)

    for plan in ("premium", "business"):
        pay_q = await db.execute(
            select(
                func.coalesce(func.sum(Payment.amount), 0),
                func.count(Payment.id),
                func.count(func.distinct(Payment.user_id)),
            ).where(
                Payment.status == "succeeded",
                Payment.kind == "subscription",
                Payment.plan == plan,
                or_(
                    Payment.paid_at >= since,
                    and_(Payment.paid_at.is_(None), Payment.created_at >= since),
                ),
            )
        )
        revenue, tx_count, paying_users = pay_q.one()
        revenue_d = Decimal(str(revenue or 0))
        paying = int(paying_users or 0)
        txs = int(tx_count or 0)

        active = int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(Subscription)
                    .where(
                        Subscription.plan == plan,
                        Subscription.is_active.is_(True),
                    )
                )
            ).scalar_one()
            or 0
        )

        tenure_rows = (
            await db.execute(
                select(Subscription.started_at, Subscription.expires_at)
                .where(
                    Subscription.plan == plan,
                    Subscription.is_active.is_(True),
                    Subscription.started_at.is_not(None),
                )
                .limit(2000)
            )
        ).all()
        months_list: list[float] = []
        now = datetime.now(UTC)
        for started, expires in tenure_rows:
            if started is None:
                continue
            end = expires if expires and expires > started else now
            months_list.append(max(0.25, (end - started).total_seconds() / (86400 * 30.44)))
        avg_months = round(sum(months_list) / len(months_list), 2) if months_list else 0.0

        arpu = float(revenue_d / paying) if paying else 0.0
        avg_tx_per_user = (txs / paying) if paying else 0.0
        ltv = round(arpu * max(1.0, avg_months / 1.0) * 0.35 + arpu, 2) if paying else 0.0
        ltv_window = round(float(revenue_d / paying), 2) if paying else 0.0

        monthly_base = price_base.get(plan)
        catalog_price = float(monthly_base) if monthly_base else 0.0

        out["plans"][plan] = {
            "active_subscribers": active,
            "paying_users": paying,
            "transactions": txs,
            "revenue": float(revenue_d),
            "arpu_window": round(arpu, 2),
            "ltv_window": ltv_window,
            "ltv_estimated": ltv,
            "avg_tenure_months": avg_months,
            "avg_transactions_per_user": round(avg_tx_per_user, 2),
            "catalog_monthly_usd": catalog_price,
        }

    prem = out["plans"]["premium"]
    biz = out["plans"]["business"]
    out["delta"] = {
        "ltv_window": round(biz["ltv_window"] - prem["ltv_window"], 2),
        "arpu_window": round(biz["arpu_window"] - prem["arpu_window"], 2),
        "revenue": round(biz["revenue"] - prem["revenue"], 2),
        "active_subscribers": biz["active_subscribers"] - prem["active_subscribers"],
        "winner": (
            "business"
            if biz["ltv_window"] > prem["ltv_window"]
            else ("premium" if prem["ltv_window"] > biz["ltv_window"] else "tie")
        ),
    }
    return out


async def subscription_hub(db: AsyncSession, *, days: int = 90) -> dict[str, Any]:
    """One payload for admin Obunalar dashboard tabs."""
    plans = await list_plan_settings(db)
    policy = await get_policy(db)
    cohort = await cohort_analytics(db, days=days)
    grants = await grant_audit(db, limit=30, days=days)
    reminders = await expiry_reminders(db)
    ltv = await ltv_compare(db, days=max(days, 180))
    return {
        "plans": plans["plans"],
        "period_discounts": plans["period_discounts"],
        "policy": policy,
        "cohort": cohort,
        "grants": grants,
        "reminders": reminders,
        "ltv": ltv,
    }
