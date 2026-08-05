"""Shared payment orchestration for Click + Paddle (+ legacy mock/stripe)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import User
from app.payments.base import is_paid, amount_str
from app.payments.click import ClickProvider
from app.payments.paddle import PaddleProvider
from app.payments.tax import PAYMENT_TAX_PERCENT, apply_payment_tax, tax_meta
from app.services.subscription import (
    activate_paid_subscription,
    billing_cycle_code,
    compute_period_price,
    normalize_billing_months,
)

ProviderName = Literal["click", "paddle", "multicard"]


async def activate_subscription(
    db: AsyncSession,
    user_id: int,
    *,
    plan: str,
    billing_cycle: str,
    auto_renew: bool = False,
) -> None:
    """Shared by Click + Paddle webhooks (TZ 5.4 / 5.6 / 5.7).

    expires_at: same-plan renew stacks remaining time; plan change restarts from now.
    auto_renew: Click=False (one-shot); Paddle=True (MoR can manage recurring).
    """
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(
            message="Foydalanuvchi topilmadi",
            error_code="USER_NOT_FOUND",
            status_code=404,
        )
    await activate_paid_subscription(
        db,
        user,
        plan=plan,  # type: ignore[arg-type]
        billing_cycle=billing_cycle,
        auto_renew=auto_renew,
    )


async def mark_payment_paid(
    db: AsyncSession,
    payment: Payment,
    *,
    provider_transaction_id: str | None,
    raw_event: dict[str, Any] | None = None,
) -> None:
    if is_paid(payment.status):
        return
    payment.status = "paid"
    payment.paid_at = datetime.now(UTC)
    if provider_transaction_id:
        payment.provider_transaction_id = provider_transaction_id
    if raw_event is not None:
        payment.raw_payload = {**(payment.raw_payload or {}), "paid_event": raw_event}
    await db.flush()


async def _cancel_pending_for_user(
    db: AsyncSession,
    user_id: int,
    *,
    provider: str,
) -> None:
    result = await db.execute(
        select(Payment)
        .where(
            Payment.user_id == user_id,
            Payment.kind == "subscription",
            Payment.status == "pending",
            Payment.provider == provider,
        )
        .with_for_update()
    )
    for row in result.scalars().all():
        meta = row.meta or {}
        # Do not cancel in-flight provider sessions (Prepare already done / Paddle txn exists).
        if meta.get("click_prepare_id"):
            continue
        if row.provider_transaction_id:
            continue
        row.status = "cancelled"
    await db.flush()


async def _find_recent_pending(
    db: AsyncSession,
    user_id: int,
    *,
    provider: str,
    plan: str,
    billing_cycle: str,
    within_minutes: int = 30,
) -> Payment | None:
    cutoff = datetime.now(UTC) - timedelta(minutes=within_minutes)
    result = await db.execute(
        select(Payment)
        .where(
            Payment.user_id == user_id,
            Payment.kind == "subscription",
            Payment.status == "pending",
            Payment.provider == provider,
            Payment.plan == plan,
            Payment.billing_cycle == billing_cycle,
            Payment.created_at >= cutoff,
        )
        .order_by(Payment.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


def _provider_instance(name: ProviderName):
    if name == "click":
        return ClickProvider()
    if name == "paddle":
        return PaddleProvider()
    if name == "multicard":
        from app.payments.multicard import MulticardProvider

        return MulticardProvider()
    raise AppError(
        message="Noto'g'ri to'lov provayderi",
        error_code="INVALID_PROVIDER",
        status_code=400,
    )


async def create_subscription_checkout(
    db: AsyncSession,
    user: User,
    *,
    plan: str,
    billing_cycle: str,
    provider: str,
) -> dict[str, Any]:
    # Temporary product policy: only Click · UZS is live.
    # Ignore paddle/multicard from older clients so checkout never dead-ends on Visa/Payme.
    provider_name = (provider or "click").strip().lower()
    if provider_name != "click":
        provider_name = "click"
    if plan not in {"premium", "business"}:
        raise AppError(
            message="Pullik tarif tanlang",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    months = normalize_billing_months(billing_cycle)
    cycle = billing_cycle_code(months)
    from app.services.subscription_admin import load_monthly_base

    monthly = await load_monthly_base(db)
    amount_usd, _, _ = compute_period_price(plan, months, monthly_base=monthly)

    settings = get_settings()
    policy = (settings.payment_pending_policy or "cancel_and_recreate").strip().lower()

    existing = await _find_recent_pending(
        db,
        user.id,
        provider=provider_name,
        plan=plan,
        billing_cycle=cycle,
    )
    if existing is not None:
        if policy == "reject":
            raise AppError(
                message="Faol pending to'lov mavjud",
                error_code="PAYMENT_ALREADY_PENDING",
                status_code=409,
                extra={"payment_id": existing.id},
            )
        if policy == "return_existing":
            impl = _provider_instance(provider_name)  # type: ignore[arg-type]
            return await impl.create_checkout(existing)
        # Default (ideal): cancel_and_recreate — yangi checkout eski pendingni yopadi.
        await _cancel_pending_for_user(db, user.id, provider=provider_name)

    from app.payments.fx import ensure_cbu_rate, rate_meta, usd_to_uzs
    from app.payments.pricing import resolve_uzs_charge
    from app.payments.tax import PAYMENT_TAX_PERCENT

    if provider_name in {"click", "multicard"}:
        cbu_rate = await ensure_cbu_rate()
        catalog = usd_to_uzs(amount_usd, rate=cbu_rate)
        currency = "UZS"
        base_amount, tax_amount, amount, tax_fields = resolve_uzs_charge(catalog)
        fx_fields = {
            "amount_usd": f"{amount_usd:.2f}",
            **rate_meta(),
        }
    else:
        from app.payments.tax import apply_payment_tax, tax_meta

        base_amount, tax_amount, amount = apply_payment_tax(amount_usd)
        tax_fields = tax_meta(base_amount, tax_amount, amount)
        currency = "USD"
        fx_fields = {"amount_usd": f"{amount_usd:.2f}"}

    if amount <= 0:
        raise AppError(
            message="To'lov summasi 0 dan katta bo'lishi kerak",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    payment = Payment(
        user_id=user.id,
        kind="subscription",
        status="pending",
        provider=provider_name,
        amount=amount,
        currency=currency,
        plan=plan,
        billing_cycle=cycle,
        meta={
            **fx_fields,
            **tax_fields,
        },
        raw_payload={},
    )
    db.add(payment)
    await db.flush()

    impl = _provider_instance(provider_name)  # type: ignore[arg-type]
    checkout = await impl.create_checkout(payment)
    await db.flush()
    checkout = {
        **checkout,
        "amount_before_tax": f"{base_amount}",
        "tax_amount": f"{tax_amount}",
        "tax_percent": PAYMENT_TAX_PERCENT,
        "amount": checkout.get("amount") or amount_str(payment.amount),
        "amount_usd": fx_fields.get("amount_usd"),
        "usd_uzs_rate": fx_fields.get("usd_uzs_rate"),
        "fx_source": fx_fields.get("fx_source"),
        "fx_date": fx_fields.get("fx_date"),
    }
    return checkout
