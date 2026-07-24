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

PaymentKind = Literal["subscription", "number", "super_group"]

SUPER_GROUP_PRICE = Decimal("10.00")


def _compute_subscription_amount(plan: str, billing_cycle: str) -> tuple[Decimal, int, str]:
    months = normalize_billing_months(billing_cycle)
    total, _per_month, _savings = compute_period_price(plan, months)
    return total, months, billing_cycle_code(months)

def _resolve_provider() -> str:
    settings = get_settings()
    if settings.payment_provider == "stripe" and settings.stripe_secret_key:
        return "stripe"
    if settings.is_production and not settings.allow_mock_payments:
        raise AppError(
            message="To'lov provayderi sozlanmagan",
            error_code="PAYMENT_INVALID",
            status_code=503,
        )
    return "mock"


def _serialize_payment(payment: Payment) -> dict[str, Any]:
    return {
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


def _checkout_description(payment: Payment) -> str:
    if payment.kind == "subscription":
        return f"AnyLang {payment.plan} ({payment.billing_cycle})"
    if payment.kind == "super_group":
        return f"AnyLang Super Group #{(payment.meta or {}).get('chat_id')}"
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
    promo_code: str | None = None,
) -> dict[str, Any]:
    amount: Decimal
    currency = "USD"
    meta: dict[str, Any] = {}
    amount_before: Decimal | None = None
    discount_amount = Decimal("0.00")
    applied_promo: str | None = None

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
        amount, months, cycle_code = _compute_subscription_amount(plan, billing_cycle)
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
    else:
        raise AppError(message="Noto'g'ri to'lov turi", error_code="PAYMENT_INVALID", status_code=400)

    if amount <= 0:
        raise AppError(
            message="To'lov summasi 0 dan katta bo'lishi kerak",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    provider = _resolve_provider()
    payment = Payment(
        user_id=user.id,
        kind=kind,
        status="pending",
        provider=provider,
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

    if provider == "mock":
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
