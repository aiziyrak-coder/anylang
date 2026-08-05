from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import User
from app.services import numbers as numbers_service
from app.services import promo as promo_service
from app.services.subscription import (
    billing_cycle_code,
    compute_period_price,
    normalize_billing_months,
    activate_paid_subscription,
)
from app.services.users import load_user_for_response, serialize_user

PaymentKind = Literal["subscription", "number", "super_group", "product_top", "account_slot"]

SUPER_GROUP_PRICE = Decimal("10.00")
ACCOUNT_SLOT_PRICE = Decimal("10.00")
PRODUCT_TOP_PRICE_USD = Decimal("30.00")
PRODUCT_TOP_DAYS = 7
PRODUCT_TOP_SLOTS = 10


def _compute_subscription_amount(plan: str, billing_cycle: str) -> tuple[Decimal, int, str]:
    months = normalize_billing_months(billing_cycle)
    total, _per_month, _savings = compute_period_price(plan, months)
    return total, months, billing_cycle_code(months)


async def _compute_subscription_amount_db(
    db: AsyncSession, plan: str, billing_cycle: str
) -> tuple[Decimal, int, str]:
    from app.services.subscription_admin import load_monthly_base

    months = normalize_billing_months(billing_cycle)
    monthly = await load_monthly_base(db)
    total, _per_month, _savings = compute_period_price(
        plan, months, monthly_base=monthly
    )
    return total, months, billing_cycle_code(months)

def _resolve_provider() -> str:
    settings = get_settings()
    if settings.payment_provider == "multicard" or (
        settings.multicard_application_id
        and settings.multicard_secret
        and settings.multicard_store_id > 0
    ):
        return "multicard"
    if settings.payment_provider == "stripe" and settings.stripe_secret_key:
        return "stripe"
    if settings.payment_provider == "click" and (
        settings.click_merchant_id and settings.click_service_id and settings.click_secret_key
    ):
        return "click"
    if settings.payment_provider == "paddle" and settings.paddle_api_key:
        return "paddle"
    if settings.is_production and not settings.allow_mock_payments:
        raise AppError(
            message="To'lov provayderi sozlanmagan",
            error_code="PAYMENT_INVALID",
            status_code=503,
        )
    return "mock"


def _serialize_payment(payment: Payment) -> dict[str, Any]:
    meta = payment.meta or {}
    out: dict[str, Any] = {
        "id": payment.id,
        "status": payment.status,
        "provider": payment.provider,
        "amount": f"{payment.amount:.2f}",
        "currency": payment.currency,
        "kind": payment.kind,
        "plan": payment.plan,
        "billing_cycle": payment.billing_cycle,
        "number": payment.number,
        "paid_at": payment.paid_at,
        "created_at": payment.created_at,
    }
    for key in ("amount_before_tax", "tax_amount", "amount_with_tax"):
        val = meta.get(key)
        if val is not None and str(val).strip():
            out[key] = str(val)
    tax_pct = meta.get("tax_percent")
    if tax_pct is not None:
        try:
            out["tax_percent"] = int(tax_pct)
        except (TypeError, ValueError):
            out["tax_percent"] = 2
    return out


def _checkout_description(payment: Payment) -> str:
    if payment.kind == "subscription":
        return f"AnyLang {payment.plan} ({payment.billing_cycle})"
    if payment.kind == "super_group":
        return f"AnyLang Super Group #{(payment.meta or {}).get('chat_id')}"
    if payment.kind == "account_slot":
        return "AnyLang extra account slot"
    if payment.kind == "product_top":
        return f"AnyLang TOP boost #{(payment.meta or {}).get('product_id')}"
    return f"AnyLang number {payment.number}"


async def _get_owned_payment(
    db: AsyncSession,
    user: User,
    payment_id: int,
) -> Payment:
    payment = await db.get(Payment, payment_id)
    if payment is None or payment.user_id != user.id:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)
    return payment


async def create_checkout(
    db: AsyncSession,
    user: User,
    *,
    kind: PaymentKind,
    plan: str | None = None,
    billing_cycle: str | None = None,
    number: str | None = None,
    chat_id: int | None = None,
    product_id: int | None = None,
    product_top_mode: str | None = None,
    promo_code: str | None = None,
    provider: str | None = None,
) -> dict[str, Any]:
    # Multicard / Click / Paddle subscription path — preferred when requested or configured.
    chosen = (provider or "").strip().lower()
    settings = get_settings()
    click_ready = bool(
        settings.click_merchant_id
        and settings.click_service_id
        and settings.click_secret_key
    )
    multicard_ready = bool(
        settings.multicard_application_id
        and settings.multicard_secret
        and settings.multicard_store_id > 0
    )
    # Prefer explicit PAYMENT_PROVIDER; Click overrides Multicard when both ready.
    # While Click credentials are incomplete, fall back to Multicard so checkout stays live.
    if settings.payment_provider == "click" and click_ready:
        chosen = "click"
    elif settings.payment_provider == "click" and not click_ready and multicard_ready:
        if not chosen or chosen == "click":
            chosen = "multicard"
    elif multicard_ready and settings.payment_provider == "multicard" and not chosen:
        chosen = "multicard"
    elif not chosen and kind == "subscription":
        if settings.payment_provider in {"click", "paddle", "multicard"}:
            if settings.payment_provider == "click" and not click_ready and multicard_ready:
                chosen = "multicard"
            else:
                chosen = settings.payment_provider
        elif click_ready:
            chosen = "click"
        elif multicard_ready:
            chosen = "multicard"
        else:
            country = (getattr(user, "country", None) or "").strip().upper()
            if country == "UZ" and click_ready:
                chosen = "click"
            elif settings.paddle_api_key and settings.paddle_webhook_secret:
                chosen = "paddle"

    if kind == "subscription" and chosen in {"click", "paddle", "multicard"}:
        from app.payments.service import create_subscription_checkout

        if not plan or plan == "basic":
            raise AppError(
                message="Pullik tarif tanlang",
                error_code="PAYMENT_INVALID",
                status_code=400,
            )
        data = await create_subscription_checkout(
            db,
            user,
            plan=plan,
            billing_cycle=billing_cycle or "monthly",
            provider=chosen,
        )
        payment = await db.get(Payment, int(data["payment_id"]))
        assert payment is not None
        out = _serialize_payment(payment)
        out["checkout_url"] = data["checkout_url"]
        out["mock_confirm"] = False
        out["client_secret"] = None
        out["stripe_session_id"] = None
        return out

    amount: Decimal
    currency = "USD"
    meta: dict[str, Any] = {}
    amount_before: Decimal | None = None
    discount_amount = Decimal("0.00")
    applied_promo: str | None = None
    resolved: str | None = None

    if kind == "subscription":
        if not plan or plan == "basic":
            raise AppError(
                message="Pullik tarif tanlang",
                error_code="PAYMENT_INVALID",
                status_code=400,
            )
        if not billing_cycle:
            raise AppError(
                message="To'lov davri (1/3/6/12 oy) talab qilinadi",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        amount, months, cycle_code = await _compute_subscription_amount_db(
            db, plan, billing_cycle
        )
        billing_cycle = cycle_code
        amount_before = amount
        if promo_code and promo_code.strip():
            preview = await promo_service.validate_promo_for_checkout(
                db,
                user,
                code=promo_code,
                plan=plan,
                months=months,
                amount=amount,
            )
            discount_amount = Decimal(preview["discount_amount"])
            amount = Decimal(preview["amount_after"])
            applied_promo = preview["code"]
            meta.update(
                {
                    "promo_id": preview["promo_id"],
                    "promo_code": applied_promo,
                    "amount_before": preview["amount_before"],
                    "discount_amount": preview["discount_amount"],
                }
            )
    elif kind == "number":
        if not number:
            raise AppError(message="Raqam talab qilinadi", error_code="VALIDATION_ERROR", status_code=400)
        number, group, amount = await numbers_service.resolve_number_for_purchase(db, user, number)
        currency = group.currency
    elif kind == "super_group":
        if chat_id is None:
            raise AppError(message="chat_id talab qilinadi", error_code="VALIDATION_ERROR", status_code=400)
        from app.services.group_admin import _require_group_admin

        chat, _ = await _require_group_admin(db, chat_id, user.id, owner_only=True)
        if chat.is_super:
            raise AppError(
                message="Guruh allaqachon Super",
                error_code="ALREADY_SUPER",
                status_code=400,
            )
        amount = SUPER_GROUP_PRICE
        meta = {"chat_id": chat_id}
    elif kind == "account_slot":
        from app.services.users import max_purchasable_account_slots

        if not user.is_business:
            raise AppError(
                message="Qo'shimcha hisob slotlari faqat biznes akkaunt uchun",
                error_code="BUSINESS_REQUIRED",
                status_code=403,
            )
        extras = int(getattr(user, "extra_account_slots", 0) or 0)
        if max_purchasable_account_slots(is_business=True, extra_account_slots=extras) <= 0:
            raise AppError(
                message="Maksimal 10 ta hisob — boshqa slot sotib olib bo'lmaydi",
                error_code="ACCOUNT_SLOTS_MAX",
                status_code=400,
            )
        amount = ACCOUNT_SLOT_PRICE
        meta = {"extra_before": extras}
    elif kind == "product_top":
        if product_id is None:
            raise AppError(
                message="product_id talab qilinadi",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        from app.payments.fx import usd_to_uzs
        from app.services.products import prepare_product_top_checkout

        _, resolved_mode = await prepare_product_top_checkout(
            db,
            user=user,
            product_id=product_id,
            mode=product_top_mode or "boost",
        )
        amount_usd = PRODUCT_TOP_PRICE_USD
        # Multicard hosts card/Payme/Click/Visa/MC — prefer it when configured.
        if multicard_ready and (not chosen or chosen == "multicard"):
            amount = usd_to_uzs(amount_usd)
            currency = "UZS"
            resolved = "multicard"
        elif chosen == "click" or (
            not chosen
            and (getattr(user, "country", None) or "").strip().upper() == "UZ"
        ):
            from app.payments.click import ClickProvider

            click = ClickProvider()
            if click.is_configured():
                amount = usd_to_uzs(amount_usd)
                currency = "UZS"
                resolved = "click"
            else:
                amount = amount_usd
                currency = "USD"
        else:
            amount = amount_usd
            currency = "USD"
        meta = {
            "product_id": int(product_id),
            "days": PRODUCT_TOP_DAYS,
            "amount_usd": f"{amount_usd:.2f}",
            "mode": resolved_mode,
            "slots": PRODUCT_TOP_SLOTS,
        }
    else:
        raise AppError(message="Noto'g'ri to'lov turi", error_code="PAYMENT_INVALID", status_code=400)

    if amount <= 0:
        raise AppError(
            message="To'lov summasi 0 dan katta bo'lishi kerak",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    if resolved is None:
        resolved = _resolve_provider()

    # Multicard hosted checkout for non-subscription kinds (UZS).
    if resolved == "multicard" and kind != "subscription":
        from app.payments.fx import usd_to_uzs

        if currency.upper() == "USD":
            amount = usd_to_uzs(amount)
            currency = "UZS"
            meta = {**meta, "amount_usd_original": True}

    # Click non-subscription UZS path.
    if resolved == "click" and kind != "subscription" and currency.upper() == "USD":
        from app.payments.fx import usd_to_uzs

        amount = usd_to_uzs(amount)
        currency = "UZS"
        meta = {**meta, "amount_usd_original": True}

    from app.payments.pricing import resolve_uzs_charge
    from app.payments.tax import apply_payment_tax, tax_meta

    if currency.upper() == "UZS":
        base_amount, tax_amount, amount, tax_fields = resolve_uzs_charge(amount)
        meta = {**meta, **tax_fields}
    else:
        base_amount, tax_amount, amount = apply_payment_tax(amount)
        meta = {**meta, **tax_meta(base_amount, tax_amount, amount)}

    payment = Payment(
        user_id=user.id,
        kind=kind,
        status="pending",
        provider=resolved,
        amount=amount,
        currency=currency,
        plan=plan,
        billing_cycle=billing_cycle,
        number=number,
        meta=meta,
    )
    db.add(payment)
    await db.flush()

    base = _serialize_payment(payment)
    base["client_secret"] = None
    if amount_before is not None:
        base["amount_before"] = f"{amount_before:.2f}"
        base["discount_amount"] = f"{discount_amount:.2f}"
        base["promo_code"] = applied_promo

    if resolved == "multicard":
        from app.payments.multicard import MulticardProvider

        data = await MulticardProvider().create_checkout(payment)
        base["checkout_url"] = data.get("checkout_url")
        base["mock_confirm"] = False
        base["stripe_session_id"] = None
        return base

    if resolved == "click":
        from app.payments.click import ClickProvider

        data = await ClickProvider().create_checkout(payment)
        base["checkout_url"] = data.get("checkout_url")
        base["mock_confirm"] = False
        base["stripe_session_id"] = None
        return base

    if resolved == "mock":
        base["mock_confirm"] = True
        return base

    settings = get_settings()
    try:
        import stripe
    except ImportError as exc:
        raise AppError(
            message="To'lov provayderi sozlanmagan. Keyinroq urinib ko'ring",
            error_code="PAYMENT_UNAVAILABLE",
            status_code=503,
        ) from exc

    stripe.api_key = settings.stripe_secret_key
    session = stripe.checkout.Session.create(
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": currency.lower(),
                    "product_data": {"name": _checkout_description(payment)},
                    "unit_amount": int(amount * 100),
                },
                "quantity": 1,
            }
        ],
        success_url=f"{settings.stripe_success_url}?session_id={{CHECKOUT_SESSION_ID}}",
        cancel_url=settings.stripe_cancel_url,
        metadata={
            "payment_id": str(payment.id),
            "user_id": str(user.id),
            "kind": kind,
        },
        client_reference_id=str(payment.id),
    )

    payment.stripe_session_id = session.id
    await db.flush()

    base["checkout_url"] = session.url
    base["stripe_session_id"] = session.id
    base["mock_confirm"] = False
    return base

async def get_payment(db: AsyncSession, user: User, payment_id: int) -> dict[str, Any]:
    payment = await _get_owned_payment(db, user, payment_id)
    if payment.provider == "multicard" and payment.status == "pending":
        from app.payments.multicard import sync_payment_status

        payment = await sync_payment_status(db, payment)
    return _serialize_payment(payment)


async def confirm_mock(db: AsyncSession, user: User, payment_id: int) -> dict[str, Any]:
    settings = get_settings()
    if not settings.mock_payments_allowed:
        raise AppError(
            message="Mock to'lov productionda o'chirilgan",
            error_code="PAYMENT_INVALID",
            status_code=403,
        )

    result = await db.execute(
        select(Payment).where(Payment.id == payment_id).with_for_update()
    )
    payment = result.scalar_one_or_none()
    if payment is None or payment.user_id != user.id:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)

    if payment.provider != "mock":
        raise AppError(
            message="Faqat mock to'lov tasdiqlanadi",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )
    if payment.status != "pending":
        raise AppError(
            message="To'lov allaqachon qayta ishlangan",
            error_code="PAYMENT_ALREADY_PROCESSED",
            status_code=409,
        )

    await _mark_succeeded(db, payment)
    user_data = await apply_payment(db, payment)
    return {
        "payment": _serialize_payment(payment),
        "user": user_data,
    }


async def _mark_succeeded(db: AsyncSession, payment: Payment) -> None:
    if payment.status == "succeeded":
        raise AppError(
            message="To'lov allaqachon qayta ishlangan",
            error_code="PAYMENT_ALREADY_PROCESSED",
            status_code=409,
        )

    payment.status = "succeeded"
    payment.paid_at = datetime.now(UTC)
    await db.flush()


async def apply_payment(db: AsyncSession, payment: Payment) -> dict[str, Any]:
    result = await db.execute(
        select(User)
        .where(User.id == payment.user_id)
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)

    try:
        if payment.kind == "subscription":
            if not payment.plan or payment.plan == "basic" or not payment.billing_cycle:
                raise AppError(message="Noto'g'ri obuna to'lovi", error_code="PAYMENT_INVALID", status_code=400)
            await activate_paid_subscription(
                db,
                user,
                plan=payment.plan,  # type: ignore[arg-type]
                billing_cycle=payment.billing_cycle,  # type: ignore[arg-type]
            )
            promo_id = (payment.meta or {}).get("promo_id")
            if promo_id:
                await promo_service.redeem_promo_on_payment(
                    db,
                    promo_id=int(promo_id),
                    user_id=user.id,
                    payment_id=payment.id,
                    amount_before=Decimal(str((payment.meta or {}).get("amount_before") or payment.amount)),
                    discount_amount=Decimal(str((payment.meta or {}).get("discount_amount") or "0")),
                    amount_after=payment.amount,
                )
        elif payment.kind == "number":
            if not payment.number:
                raise AppError(message="Noto'g'ri raqam to'lovi", error_code="PAYMENT_INVALID", status_code=400)
            await numbers_service.assign_purchased_number(db, user, payment.number)
        elif payment.kind == "super_group":
            chat_id = (payment.meta or {}).get("chat_id")
            if not chat_id:
                raise AppError(message="Noto'g'ri Super Group to'lovi", error_code="PAYMENT_INVALID", status_code=400)
            from app.services.group_admin import mark_chat_super

            await mark_chat_super(db, chat_id=int(chat_id), payment_id=payment.id)
        elif payment.kind == "account_slot":
            from app.services.users import max_purchasable_account_slots

            if not user.is_business:
                raise AppError(
                    message="Qo'shimcha hisob slotlari faqat biznes akkaunt uchun",
                    error_code="BUSINESS_REQUIRED",
                    status_code=403,
                )
            extras = int(getattr(user, "extra_account_slots", 0) or 0)
            if max_purchasable_account_slots(is_business=True, extra_account_slots=extras) <= 0:
                raise AppError(
                    message="Maksimal 10 ta hisob",
                    error_code="ACCOUNT_SLOTS_MAX",
                    status_code=400,
                )
            user.extra_account_slots = extras + 1
            await db.flush()
        elif payment.kind == "product_top":
            from app.services.products import activate_product_top_from_payment

            await activate_product_top_from_payment(db, payment)
        else:
            raise AppError(message="Noto'g'ri to'lov turi", error_code="PAYMENT_INVALID", status_code=400)
    except AppError as exc:
        if payment.kind == "number" and exc.error_code in {"NUMBER_TAKEN", "NUMBER_RESERVED"}:
            payment.status = "needs_refund"
            await db.flush()
            raise AppError(
                message="To'lov qabul qilindi, lekin raqam berilmadi — qaytarish kerak",
                error_code="PAYMENT_FULFILLMENT_FAILED",
                status_code=409,
                extra={"payment_id": payment.id, "number": payment.number},
            ) from exc
        raise

    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return await serialize_user(loaded, db)


async def handle_stripe_webhook(
    db: AsyncSession,
    payload_bytes: bytes,
    sig_header: str,
) -> dict[str, str]:
    settings = get_settings()
    if not settings.stripe_webhook_secret:
        raise AppError(
            message="Stripe webhook sozlanmagan",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    try:
        import stripe
    except ImportError as exc:
        raise AppError(
            message="To'lov provayderi sozlanmagan. Keyinroq urinib ko'ring",
            error_code="PAYMENT_UNAVAILABLE",
            status_code=503,
        ) from exc

    try:
        event = stripe.Webhook.construct_event(
            payload_bytes,
            sig_header,
            settings.stripe_webhook_secret,
        )
    except stripe.SignatureVerificationError as exc:
        raise AppError(
            message="Stripe imzo noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=400,
        ) from exc
    except ValueError as exc:
        raise AppError(
            message="Stripe payload noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=400,
        ) from exc

    if event["type"] != "checkout.session.completed":
        return {"status": "ignored"}

    session = event["data"]["object"]
    session_id = session.get("id")
    if not session_id:
        return {"status": "ignored"}

    result = await db.execute(
        select(Payment).where(Payment.stripe_session_id == session_id).with_for_update()
    )
    payment = result.scalar_one_or_none()
    if payment is None:
        raise AppError(message="To'lov topilmadi", error_code="PAYMENT_NOT_FOUND", status_code=404)

    if payment.status == "succeeded":
        return {"status": "already_processed"}
    if payment.status == "needs_refund":
        await apply_payment(db, payment)
        return {"status": "reprocessed"}
    if payment.status != "pending":
        return {"status": "ignored"}

    payment.stripe_payment_intent_id = session.get("payment_intent")
    await _mark_succeeded(db, payment)
    await apply_payment(db, payment)
    return {"status": "processed"}
