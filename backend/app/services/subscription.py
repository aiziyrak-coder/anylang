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
# Canonical: "1" | "3" | "6" | "12". Legacy aliases: monthly→1, yearly→12
BillingCycle = str
AppLanguage = Literal["uz_UZ", "ru_RU", "us_US"]

PLAN_ORDER = {"basic": 0, "premium": 1, "business": 2}

# Oyiga baza narx (USD). Uzun muddat — foiz chegirma.
PLAN_MONTHLY_BASE: dict[str, Decimal | None] = {
    "basic": None,
    "premium": Decimal("4.99"),
    "business": Decimal("19.99"),
}

# Muddat → umumiy summadan chegirma (ko'proq olsangiz — arzonroq).
PERIOD_DISCOUNT: dict[int, Decimal] = {
    1: Decimal("0.00"),
    3: Decimal("0.10"),  # 10%
    6: Decimal("0.15"),  # 15%
    12: Decimal("0.20"),  # 20%
}

# Legacy PLAN_PRICES (payments/admin eski kod uchun).
PLAN_PRICES: dict[str, dict[str, Decimal | None]] = {
    "basic": {"monthly_price": None, "yearly_price": None},
    "premium": {
        "monthly_price": PLAN_MONTHLY_BASE["premium"],
        "yearly_price": (PLAN_MONTHLY_BASE["premium"] or Decimal("0"))
        * (Decimal("1") - PERIOD_DISCOUNT[12]),
    },
    "business": {
        "monthly_price": PLAN_MONTHLY_BASE["business"],
        "yearly_price": (PLAN_MONTHLY_BASE["business"] or Decimal("0"))
        * (Decimal("1") - PERIOD_DISCOUNT[12]),
    },
}


def normalize_billing_months(billing_cycle: str | int | None) -> int:
    """monthly/yearly/1/3/6/12 → months int."""
    if billing_cycle is None:
        return 1
    raw = str(billing_cycle).strip().lower()
    aliases = {
        "monthly": 1,
        "month": 1,
        "m1": 1,
        "1m": 1,
        "1": 1,
        "3": 3,
        "m3": 3,
        "3m": 3,
        "6": 6,
        "m6": 6,
        "6m": 6,
        "yearly": 12,
        "year": 12,
        "annual": 12,
        "12": 12,
        "m12": 12,
        "12m": 12,
    }
    if raw in aliases:
        return aliases[raw]
    try:
        months = int(raw)
    except ValueError as exc:
        raise AppError(
            message="To'lov davri noto'g'ri (1/3/6/12 oy)",
            error_code="VALIDATION_ERROR",
            status_code=400,
        ) from exc
    if months not in PERIOD_DISCOUNT:
        raise AppError(
            message="To'lov davri 1, 3, 6 yoki 12 oy bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    return months


def billing_cycle_code(months: int) -> str:
    return str(months)


def compute_period_price(plan: str, months: int) -> tuple[Decimal, Decimal, int]:
    """Returns (total, per_month_effective, savings_percent vs 1 month)."""
    base = PLAN_MONTHLY_BASE.get(plan)
    if base is None:
        raise AppError(message="Tarif bepul", error_code="PAYMENT_INVALID", status_code=400)
    months = normalize_billing_months(months)
    discount = PERIOD_DISCOUNT[months]
    total = (base * months * (Decimal("1") - discount)).quantize(Decimal("0.01"))
    per_month = (total / months).quantize(Decimal("0.01"))
    savings = int(round(float(discount) * 100))
    return total, per_month, savings


def period_catalog_for_plan(plan: str) -> list[dict]:
    base = PLAN_MONTHLY_BASE.get(plan)
    if base is None:
        return []
    out: list[dict] = []
    for months in (1, 3, 6, 12):
        total, per_month, savings = compute_period_price(plan, months)
        out.append(
            {
                "months": months,
                "code": billing_cycle_code(months),
                "total": f"{total:.2f}",
                "per_month": f"{per_month:.2f}",
                "savings_percent": savings if savings > 0 else None,
            }
        )
    return out


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

PLAN_BADGES: dict[str, dict[str, str]] = {
    "uz_UZ": {"business": "SOTUVCHILAR"},
    "ru_RU": {"business": "ПРОДАВЦЫ"},
    "us_US": {"business": "SELLERS"},
}


def _resolve_language(language: str | None) -> str:
    if language in FEATURE_TEXTS:
        return language  # type: ignore[return-value]
    # Accept short codes from mobile session store aliases.
    aliases = {"uz": "uz_UZ", "ru": "ru_RU", "en": "us_US", "us": "us_US"}
    if language:
        short = language.split("_")[0].split("-")[0].lower()
        mapped = aliases.get(short)
        if mapped:
            return mapped
    return "uz_UZ"


def get_plans(*, language: str | None = None, billing_cycle: str | None = None) -> dict:
    lang = _resolve_language(language)
    titles = PLAN_TITLES[lang]
    features_map = FEATURE_TEXTS[lang]
    badges = PLAN_BADGES[lang]
    selected_months = (
        normalize_billing_months(billing_cycle) if billing_cycle else None
    )

    plans: list[dict[str, Any]] = []
    for code in ("basic", "premium", "business"):
        base = PLAN_MONTHLY_BASE[code]
        periods = period_catalog_for_plan(code)
        yearly = next((p for p in periods if p["months"] == 12), None)
        monthly = next((p for p in periods if p["months"] == 1), None)
        plan: dict[str, Any] = {
            "code": code,
            "title": titles[code],
            "is_free": code == "basic",
            "monthly_price": monthly["per_month"] if monthly else None,
            "yearly_price": yearly["per_month"] if yearly else None,
            "yearly_total": yearly["total"] if yearly else None,
            "savings_percent": yearly["savings_percent"] if yearly else None,
            "currency": "USD",
            "badge": badges.get(code),
            "periods": periods,
            "features": [
                {"text": text, "included": included} for text, included in features_map[code]
            ],
        }
        if selected_months is not None and base is not None:
            match = next((p for p in periods if p["months"] == selected_months), None)
            if match:
                plan["selected_period"] = match
        plans.append(plan)

    return {
        "plans": plans,
        "period_options": [
            {"months": m, "code": str(m), "discount_percent": int(float(PERIOD_DISCOUNT[m]) * 100)}
            for m in (1, 3, 6, 12)
        ],
    }


def _cycle_delta(billing_cycle: str) -> timedelta:
    months = normalize_billing_months(billing_cycle)
    # Approximate calendar months.
    return timedelta(days=30 * months)


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

    months = normalize_billing_months(billing_cycle)
    cycle = billing_cycle_code(months)
    now = datetime.now(UTC)
    subscription.plan = plan
    subscription.billing_cycle = cycle
    subscription.started_at = now
    subscription.expires_at = now + _cycle_delta(cycle)
    # Stripe Checkout is one-shot (mode=payment); no auto-charge until Billing is wired.
    subscription.auto_renew = False
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
    """Downgrade expired paid subscriptions to basic. Returns count updated.

    One-shot Stripe purchases never auto-renew; expire whenever expires_at has passed.
    """
    now = datetime.now(UTC)
    result = await db.execute(
        select(Subscription).where(
            Subscription.plan != "basic",
            Subscription.is_active.is_(True),
            Subscription.expires_at.is_not(None),
            Subscription.expires_at < now,
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
