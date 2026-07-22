from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.user import BusinessProfile, Subscription, User
from app.services.users import ensure_basic_subscription, load_user_for_response, serialize_user

PlanCode = Literal["basic", "premium", "business"]
BillingCycle = Literal["monthly", "yearly"]
AppLanguage = Literal["uz_UZ", "ru_RU", "us_US"]

PLAN_ORDER = {"basic": 0, "premium": 1, "business": 2}

PLAN_PRICES: dict[str, dict[str, Decimal | None]] = {
    "basic": {"monthly_price": None, "yearly_price": None},
    "premium": {"monthly_price": Decimal("4.99"), "yearly_price": Decimal("3.99")},
    "business": {"monthly_price": Decimal("19.99"), "yearly_price": Decimal("15.99")},
}

FEATURE_TEXTS: dict[str, dict[str, list[tuple[str, bool]]]] = {
    "uz_UZ": {
        "basic": [
            ("Kuniga 20 ta tarjima", True),
            ("Matn & ovozli chat", True),
            ("Jonli muloqot rejimi", False),
        ],
        "premium": [
            ("Cheksiz tarjima", True),
            ("Jonli muloqot rejimi", True),
            ("Reklamasiz & ustuvor tezlik", True),
        ],
        "business": [
            ("Premium'dagi barchasi", True),
            ("Biznes profil & e'lonlar", True),
            ("Sertifikat & ko'rish statistikasi", True),
        ],
    },
    "ru_RU": {
        "basic": [
            ("20 переводов в день", True),
            ("Текстовый и голосовой чат", True),
            ("Режим живого общения", False),
        ],
        "premium": [
            ("Безлимитные переводы", True),
            ("Режим живого общения", True),
            ("Без рекламы и приоритетная скорость", True),
        ],
        "business": [
            ("Всё из Premium", True),
            ("Бизнес-профиль и объявления", True),
            ("Сертификаты и статистика просмотров", True),
        ],
    },
    "us_US": {
        "basic": [
            ("20 translations per day", True),
            ("Text & voice chat", True),
            ("Live conversation mode", False),
        ],
        "premium": [
            ("Unlimited translations", True),
            ("Live conversation mode", True),
            ("Ad-free & priority speed", True),
        ],
        "business": [
            ("Everything in Premium", True),
            ("Business profile & listings", True),
            ("Certificates & view statistics", True),
        ],
    },
}

PLAN_TITLES: dict[str, dict[str, str]] = {
    "uz_UZ": {"basic": "Basic", "premium": "Premium", "business": "Business"},
    "ru_RU": {"basic": "Basic", "premium": "Premium", "business": "Business"},
    "us_US": {"basic": "Basic", "premium": "Premium", "business": "Business"},
}


def _resolve_language(language: str | None) -> str:
    if language in FEATURE_TEXTS:
        return language  # type: ignore[return-value]
    return "uz_UZ"


def get_plans(*, language: str | None = None, billing_cycle: str | None = None) -> dict:
    lang = _resolve_language(language)
    titles = PLAN_TITLES[lang]
    features_map = FEATURE_TEXTS[lang]

    plans: list[dict[str, Any]] = []
    for code in ("basic", "premium", "business"):
        prices = PLAN_PRICES[code]
        plan: dict[str, Any] = {
            "code": code,
            "title": titles[code],
            "is_free": code == "basic",
            "monthly_price": str(prices["monthly_price"]) if prices["monthly_price"] is not None else None,
            "yearly_price": str(prices["yearly_price"]) if prices["yearly_price"] is not None else None,
            "currency": "USD",
            "badge": "SELLERS" if code == "business" else None,
            "features": [
                {"text": text, "included": included} for text, included in features_map[code]
            ],
        }
        if billing_cycle == "monthly":
            plan["yearly_price"] = None
        elif billing_cycle == "yearly":
            plan["monthly_price"] = None
        plans.append(plan)

    return {"plans": plans}


def _cycle_delta(billing_cycle: str) -> timedelta:
    if billing_cycle == "yearly":
        return timedelta(days=365)
    return timedelta(days=30)


async def _ensure_business_profile(db: AsyncSession, user: User) -> None:
    if user.business is not None:
        return
    profile = BusinessProfile(user_id=user.id, company_name="")
    db.add(profile)
    await db.flush()


async def activate_paid_subscription(
    db: AsyncSession,
    user: User,
    *,
    plan: PlanCode,
    billing_cycle: BillingCycle,
) -> None:
    subscription = await ensure_basic_subscription(user, db)

    now = datetime.now(UTC)
    subscription.plan = plan
    subscription.billing_cycle = billing_cycle
    subscription.started_at = now
    subscription.expires_at = now + _cycle_delta(billing_cycle)
    subscription.auto_renew = True
    subscription.is_active = True
    subscription.source = "purchase"
    if plan == "business":
        await _ensure_business_profile(db, user)

    await db.flush()


async def subscribe(
    db: AsyncSession,
    user: User,
    *,
    plan: PlanCode,
    billing_cycle: BillingCycle | None = None,
) -> dict:
    subscription = user.subscription
    if subscription is None:
        subscription = await ensure_basic_subscription(user, db)

    if subscription.plan == plan and plan != "basic" and subscription.is_active:
        if billing_cycle is None or subscription.billing_cycle == billing_cycle:
            raise AppError(
                message="Siz allaqachon shu tarifdasiz",
                error_code="ALREADY_ON_PLAN",
                status_code=400,
            )

    if plan != "basic":
        raise AppError(
            message="Pullik tarif uchun to'lov talab qilinadi",
            error_code="PAYMENT_REQUIRED",
            status_code=402,
            extra={"hint": "POST /api/v1/payments/checkout"},
        )

    subscription.plan = "basic"
    subscription.billing_cycle = None
    subscription.started_at = None
    subscription.expires_at = None
    subscription.auto_renew = False
    subscription.is_active = True
    subscription.source = "purchase"

    await db.flush()
    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return await serialize_user(loaded, db)


async def cancel_subscription(db: AsyncSession, user: User) -> dict:
    subscription = user.subscription
    if subscription is None:
        subscription = await ensure_basic_subscription(user, db)

    if subscription.plan == "basic":
        subscription.auto_renew = False
    else:
        subscription.auto_renew = False

    await db.flush()
    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return await serialize_user(loaded, db)


async def apply_bonus_subscription(
    db: AsyncSession,
    user: User,
    *,
    bonus_plan: str,
    bonus_duration_months: int,
) -> None:
    subscription = user.subscription
    if subscription is None:
        subscription = await ensure_basic_subscription(user, db)

    now = datetime.now(UTC)
    bonus_delta = timedelta(days=bonus_duration_months * 30)
    current_plan_rank = PLAN_ORDER.get(subscription.plan, 0)
    bonus_plan_rank = PLAN_ORDER.get(bonus_plan, 0)

    if current_plan_rank < bonus_plan_rank:
        subscription.plan = bonus_plan
        subscription.billing_cycle = None
        subscription.started_at = now
        subscription.expires_at = now + bonus_delta
    elif current_plan_rank == bonus_plan_rank:
        base = subscription.expires_at if subscription.expires_at and subscription.expires_at > now else now
        subscription.expires_at = base + bonus_delta
    else:
        base = subscription.expires_at if subscription.expires_at and subscription.expires_at > now else now
        subscription.expires_at = base + bonus_delta

    subscription.is_active = True
    subscription.auto_renew = False
    subscription.source = "number_bonus"

    if bonus_plan == "business":
        await _ensure_business_profile(db, user)

    await db.flush()


async def expire_subscriptions(db: AsyncSession) -> int:
    """Downgrade expired paid subscriptions to basic. Returns count updated."""
    now = datetime.now(UTC)
    result = await db.execute(
        select(Subscription).where(
            Subscription.plan != "basic",
            Subscription.is_active.is_(True),
            Subscription.expires_at.is_not(None),
            Subscription.expires_at < now,
            Subscription.auto_renew.is_(False),
        )
    )
    expired = list(result.scalars().all())
    for sub in expired:
        sub.plan = "basic"
        sub.billing_cycle = None
        sub.started_at = None
        sub.expires_at = None
        sub.auto_renew = False
        sub.is_active = True
        sub.source = "purchase"

    if expired:
        await db.flush()
    return len(expired)
