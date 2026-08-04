"""Click.uz SHOP API — Prepare / Complete + checkout URL.

Official docs: https://docs.click.uz
Signature (Prepare, action=0):
  md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id + amount + action + sign_time)
Signature (Complete, action=1):
  md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id + merchant_prepare_id
      + amount + action + sign_time)
"""

from __future__ import annotations

import hashlib
import hmac
import logging
from decimal import Decimal
from typing import Any
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import User
from app.payments.base import PaymentProvider, amount_str, is_paid

logger = logging.getLogger(__name__)

# Click error codes (SHOP API).
CLICK_OK = 0
CLICK_SIGN_FAILED = -1
CLICK_BAD_AMOUNT = -2
CLICK_ACTION_NOT_FOUND = -3
CLICK_ALREADY_PAID = -4
CLICK_USER_NOT_FOUND = -5
CLICK_TX_NOT_FOUND = -6
CLICK_UPDATE_FAILED = -7
CLICK_REQUEST_ERROR = -8
CLICK_CANCELLED = -9


class ClickProvider(PaymentProvider):
    name = "click"

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def is_configured(self) -> bool:
        s = self.settings
        return bool(
            s.click_merchant_id
            and s.click_service_id
            and s.click_secret_key
        )

    async def create_checkout(self, payment: Payment) -> dict[str, Any]:
        s = self.settings
        if not self.is_configured():
            raise AppError(
                message="Click to'lov sozlanmagan",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
        params = {
            "service_id": s.click_service_id,
            "merchant_id": s.click_merchant_id,
            "amount": amount_str(payment.amount),
            "transaction_param": str(payment.id),
            "return_url": f"{s.public_api_base_url.rstrip('/')}/billing/success",
        }
        if s.click_merchant_user_id:
            params["merchant_user_id"] = s.click_merchant_user_id
        url = f"{s.click_pay_base_url}?{urlencode(params)}"
        return {
            "payment_id": payment.id,
            "id": payment.id,
            "provider": self.name,
            "checkout_url": url,
            "amount": amount_str(payment.amount),
            "currency": payment.currency,
            "status": payment.status,
            "mock_confirm": False,
        }


def _md5(raw: str) -> str:
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


def _sign_ok(expected: str, received: str) -> bool:
    if not expected or not received:
        return False
    if len(expected) != len(received):
        return False
    return hmac.compare_digest(expected, received)


def prepare_sign(
    *,
    click_trans_id: str,
    service_id: str,
    secret_key: str,
    merchant_trans_id: str,
    amount: str,
    action: str | int,
    sign_time: str,
) -> str:
    return _md5(
        f"{click_trans_id}{service_id}{secret_key}{merchant_trans_id}"
        f"{amount}{action}{sign_time}"
    )


def complete_sign(
    *,
    click_trans_id: str,
    service_id: str,
    secret_key: str,
    merchant_trans_id: str,
    merchant_prepare_id: str,
    amount: str,
    action: str | int,
    sign_time: str,
) -> str:
    return _md5(
        f"{click_trans_id}{service_id}{secret_key}{merchant_trans_id}"
        f"{merchant_prepare_id}{amount}{action}{sign_time}"
    )


def _click_response(
    *,
    click_trans_id: str,
    merchant_trans_id: str,
    error: int,
    error_note: str,
    merchant_prepare_id: str | None = None,
    merchant_confirm_id: str | None = None,
) -> dict[str, Any]:
    out: dict[str, Any] = {
        "click_trans_id": click_trans_id,
        "merchant_trans_id": merchant_trans_id,
        "error": error,
        "error_note": error_note,
    }
    if merchant_prepare_id is not None:
        out["merchant_prepare_id"] = merchant_prepare_id
    if merchant_confirm_id is not None:
        out["merchant_confirm_id"] = merchant_confirm_id
    return out


def _norm_amount(value: str | float | Decimal) -> Decimal:
    return Decimal(str(value).replace(",", "").strip()).quantize(Decimal("0.01"))


def _service_id_ok(received: str, expected: str) -> bool:
    if not expected:
        return True  # not configured — signature already gates
    return str(received).strip() == str(expected).strip()


async def handle_prepare(db: AsyncSession, payload: dict[str, Any]) -> dict[str, Any]:
    settings = get_settings()
    click_trans_id = str(payload.get("click_trans_id") or "")
    service_id = str(payload.get("service_id") or "")
    merchant_trans_id = str(payload.get("merchant_trans_id") or "")
    amount = str(payload.get("amount") or "")
    action = payload.get("action", 0)
    sign_time = str(payload.get("sign_time") or "")
    sign_string = str(payload.get("sign_string") or "")

    expected = prepare_sign(
        click_trans_id=click_trans_id,
        service_id=service_id,
        secret_key=settings.click_secret_key,
        merchant_trans_id=merchant_trans_id,
        amount=amount,
        action=action,
        sign_time=sign_time,
    )
    if not settings.click_secret_key or not _sign_ok(expected, sign_string):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_SIGN_FAILED,
            error_note="SIGN CHECK FAILED",
        )

    if not _service_id_ok(service_id, settings.click_service_id):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    try:
        payment_id = int(merchant_trans_id)
    except ValueError:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_TX_NOT_FOUND,
            error_note="Transaction does not exist",
        )

    result = await db.execute(
        select(Payment).where(Payment.id == payment_id).with_for_update()
    )
    payment = result.scalar_one_or_none()
    if payment is None or payment.provider != "click":
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_TX_NOT_FOUND,
            error_note="Transaction does not exist",
        )

    payment.raw_payload = {**(payment.raw_payload or {}), "prepare": payload}
    await db.flush()

    if is_paid(payment.status):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_prepare_id=str(payment.id),
            error=CLICK_ALREADY_PAID,
            error_note="Already paid",
        )

    if payment.status != "pending":
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    try:
        if _norm_amount(amount) != _norm_amount(payment.amount):
            return _click_response(
                click_trans_id=click_trans_id,
                merchant_trans_id=merchant_trans_id,
                error=CLICK_BAD_AMOUNT,
                error_note="Incorrect parameter amount",
            )
    except Exception:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            error=CLICK_BAD_AMOUNT,
            error_note="Incorrect parameter amount",
        )

    meta = dict(payment.meta or {})
    meta["click_prepare_id"] = str(payment.id)
    meta["click_trans_id"] = click_trans_id
    paydoc = payload.get("click_paydoc_id")
    if paydoc is not None:
        meta["click_paydoc_id"] = str(paydoc)
    payment.meta = meta
    await db.flush()

    return _click_response(
        click_trans_id=click_trans_id,
        merchant_trans_id=merchant_trans_id,
        merchant_prepare_id=str(payment.id),
        error=CLICK_OK,
        error_note="Success",
    )


async def handle_complete(db: AsyncSession, payload: dict[str, Any]) -> dict[str, Any]:
    from app.payments.service import activate_subscription, mark_payment_paid

    settings = get_settings()
    click_trans_id = str(payload.get("click_trans_id") or "")
    service_id = str(payload.get("service_id") or "")
    merchant_trans_id = str(payload.get("merchant_trans_id") or "")
    merchant_prepare_id = str(payload.get("merchant_prepare_id") or "")
    amount = str(payload.get("amount") or "")
    action = payload.get("action", 1)
    sign_time = str(payload.get("sign_time") or "")
    sign_string = str(payload.get("sign_string") or "")
    try:
        error_from_click = int(payload.get("error") or 0)
    except (TypeError, ValueError):
        error_from_click = -1

    expected = complete_sign(
        click_trans_id=click_trans_id,
        service_id=service_id,
        secret_key=settings.click_secret_key,
        merchant_trans_id=merchant_trans_id,
        merchant_prepare_id=merchant_prepare_id,
        amount=amount,
        action=action,
        sign_time=sign_time,
    )
    if not settings.click_secret_key or not _sign_ok(expected, sign_string):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_SIGN_FAILED,
            error_note="SIGN CHECK FAILED",
        )

    if not _service_id_ok(service_id, settings.click_service_id):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    try:
        payment_id = int(merchant_trans_id)
    except ValueError:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_TX_NOT_FOUND,
            error_note="Transaction does not exist",
        )

    result = await db.execute(
        select(Payment).where(Payment.id == payment_id).with_for_update()
    )
    payment = result.scalar_one_or_none()
    if payment is None or payment.provider != "click":
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_TX_NOT_FOUND,
            error_note="Transaction does not exist",
        )

    payment.raw_payload = {**(payment.raw_payload or {}), "complete": payload}
    await db.flush()

    # Idempotent success.
    if is_paid(payment.status):
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=str(payment.id),
            error=CLICK_OK,
            error_note="Success",
        )

    try:
        action_int = int(action)
    except (TypeError, ValueError):
        action_int = -1
    if action_int != 1:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_ACTION_NOT_FOUND,
            error_note="Action not found",
        )

    prepare_ok = str((payment.meta or {}).get("click_prepare_id") or "")
    if not prepare_ok:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    if merchant_prepare_id and merchant_prepare_id != prepare_ok:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    # Recover if pending was cancelled after Prepare (cancel_and_recreate race).
    if payment.status not in {"pending", "cancelled"}:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_REQUEST_ERROR,
            error_note="Error in request from Click",
        )

    if error_from_click < 0:
        payment.status = "cancelled" if error_from_click == CLICK_CANCELLED else "failed"
        await db.flush()
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=str(payment.id),
            error=error_from_click,
            error_note=str(payload.get("error_note") or "Failed"),
        )

    try:
        if _norm_amount(amount) != _norm_amount(payment.amount):
            return _click_response(
                click_trans_id=click_trans_id,
                merchant_trans_id=merchant_trans_id,
                merchant_confirm_id=merchant_prepare_id,
                error=CLICK_BAD_AMOUNT,
                error_note="Incorrect parameter amount",
            )
    except Exception:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=merchant_prepare_id,
            error=CLICK_BAD_AMOUNT,
            error_note="Incorrect parameter amount",
        )

    user_result = await db.execute(
        select(User)
        .where(User.id == payment.user_id)
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = user_result.scalar_one_or_none()
    if user is None:
        return _click_response(
            click_trans_id=click_trans_id,
            merchant_trans_id=merchant_trans_id,
            merchant_confirm_id=str(payment.id),
            error=CLICK_USER_NOT_FOUND,
            error_note="User does not exist",
        )

    await mark_payment_paid(
        db,
        payment,
        provider_transaction_id=click_trans_id,
        raw_event=payload,
    )

    meta = dict(payment.meta or {})
    meta["click_trans_id"] = click_trans_id
    paydoc = payload.get("click_paydoc_id")
    if paydoc is not None:
        meta["click_paydoc_id"] = str(paydoc)
    payment.meta = meta

    if payment.kind == "subscription" and payment.plan and payment.billing_cycle:
        await activate_subscription(
            db,
            user.id,
            plan=payment.plan,
            billing_cycle=payment.billing_cycle,
            auto_renew=False,
        )
    elif payment.kind == "product_top":
        from app.services.products import activate_product_top_from_payment

        await activate_product_top_from_payment(db, payment)
    elif payment.kind in {"number", "super_group", "account_slot"}:
        from app.services.payments import apply_payment

        # Status already "paid"; apply_payment expects pending→succeeded.
        # Call kind-specific fulfillment directly via apply helpers.
        if payment.kind == "number" and payment.number:
            from app.services import numbers as numbers_service

            await numbers_service.assign_purchased_number(db, user, payment.number)
        elif payment.kind == "super_group":
            chat_id = (payment.meta or {}).get("chat_id")
            if chat_id:
                from app.services.group_admin import mark_chat_super

                await mark_chat_super(db, chat_id=int(chat_id), payment_id=payment.id)
        elif payment.kind == "account_slot":
            from app.services.users import max_purchasable_account_slots

            if user.is_business:
                extras = int(getattr(user, "extra_account_slots", 0) or 0)
                if max_purchasable_account_slots(is_business=True, extra_account_slots=extras) > 0:
                    user.extra_account_slots = extras + 1
                    await db.flush()

    try:
        from app.payments.fiscal import submit_fiscal_items

        fiscal = await submit_fiscal_items(payment, click_payment_id=click_trans_id)
        if fiscal is not None:
            meta = dict(payment.meta or {})
            meta["fiscal"] = fiscal
            payment.meta = meta
            await db.flush()
    except Exception:
        logger.exception("Click fiscalization hook failed payment=%s", payment.id)

    return _click_response(
        click_trans_id=click_trans_id,
        merchant_trans_id=merchant_trans_id,
        merchant_confirm_id=str(payment.id),
        error=CLICK_OK,
        error_note="Success",
    )
