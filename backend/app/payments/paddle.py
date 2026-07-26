"""Paddle Billing API (Merchant of Record) — checkout + webhook.

Docs: https://developer.paddle.com
Sandbox base: https://sandbox-api.paddle.com
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import User
from app.payments.base import PaymentProvider, amount_str, is_paid

logger = logging.getLogger(__name__)


class PaddleProvider(PaymentProvider):
    name = "paddle"

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def is_configured(self) -> bool:
        s = self.settings
        return bool(s.paddle_api_key and s.paddle_webhook_secret)

    def price_id_for(self, plan: str, billing_cycle: str) -> tuple[str, int]:
        """Return (price_id, quantity). 3/6 oy → monthly price × quantity."""
        s = self.settings
        raw = str(billing_cycle or "1").strip().lower()
        if raw in {"monthly", "month", "m1", "1"}:
            key, qty = "monthly", 1
        elif raw in {"yearly", "year", "annual", "12"}:
            key, qty = "yearly", 1
        elif raw in {"3", "m3", "3m"}:
            key, qty = "monthly", 3
        elif raw in {"6", "m6", "6m"}:
            key, qty = "monthly", 6
        else:
            try:
                months = int(raw)
            except ValueError:
                months = 1
            if months >= 12:
                key, qty = "yearly", 1
            elif months in {3, 6}:
                key, qty = "monthly", months
            else:
                key, qty = "monthly", max(1, months)

        mapping = {
            ("premium", "monthly"): s.paddle_price_premium_monthly,
            ("premium", "yearly"): s.paddle_price_premium_yearly,
            ("business", "monthly"): s.paddle_price_business_monthly,
            ("business", "yearly"): s.paddle_price_business_yearly,
        }
        price_id = mapping.get((plan, key), "")
        if not price_id:
            logger.warning(
                "Paddle price_id missing for plan=%s cycle=%s key=%s",
                plan,
                billing_cycle,
                key,
            )
        return price_id, qty

    async def create_checkout(self, payment: Payment) -> dict[str, Any]:
        s = self.settings
        price_id, quantity = self.price_id_for(
            payment.plan or "", payment.billing_cycle or "1"
        )
        if not self.is_configured() or not price_id:
            if s.is_production:
                raise AppError(
                    message="Paddle to'lov sozlanmagan",
                    error_code="PAYMENT_UNAVAILABLE",
                    status_code=503,
                )
            logger.warning("Paddle not fully configured — placeholder checkout URL")
            return {
                "payment_id": payment.id,
                "id": payment.id,
                "provider": self.name,
                "checkout_url": (
                    f"{s.public_api_base_url.rstrip('/')}/billing/paddle-todo"
                    f"?payment_id={payment.id}"
                ),
                "amount": amount_str(payment.amount),
                "currency": payment.currency,
                "status": payment.status,
                "mock_confirm": False,
            }

        payload = {
            "items": [{"price_id": price_id, "quantity": quantity}],
            "custom_data": {
                "payment_id": str(payment.id),
                "user_id": str(payment.user_id),
                "plan": payment.plan,
                "billing_cycle": payment.billing_cycle,
            },
        }
        headers = {
            "Authorization": f"Bearer {s.paddle_api_key}",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{s.paddle_api_base_url.rstrip('/')}/transactions",
                json=payload,
                headers=headers,
            )
        if resp.status_code >= 400:
            logger.error("Paddle transaction create failed: %s %s", resp.status_code, resp.text)
            raise AppError(
                message="Paddle checkout yaratib bo'lmadi",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
        data = resp.json().get("data") or resp.json()
        checkout = (data.get("checkout") or {}) if isinstance(data, dict) else {}
        url = checkout.get("url") or data.get("url")
        txn_id = data.get("id")
        if txn_id:
            payment.provider_transaction_id = str(txn_id)
            meta = dict(payment.meta or {})
            meta["paddle_transaction_id"] = str(txn_id)
            payment.meta = meta
        if not url:
            raise AppError(
                message="Paddle checkout URL yo'q",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
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


def verify_paddle_signature(
    *,
    raw_body: bytes,
    signature_header: str,
    secret: str,
    max_age_seconds: int = 300,
) -> bool:
    """Verify Paddle-Signature: ts=...;h1=... (HMAC-SHA256)."""
    if not secret or not signature_header:
        return False
    ts: str | None = None
    h1_values: list[str] = []
    for chunk in signature_header.split(";"):
        chunk = chunk.strip()
        if "=" not in chunk:
            continue
        key, value = chunk.split("=", 1)
        key, value = key.strip(), value.strip()
        if key == "ts":
            ts = value
        elif key == "h1" and value:
            h1_values.append(value)
    if not ts or not h1_values:
        return False
    try:
        if abs(time.time() - int(ts)) > max_age_seconds:
            return False
    except ValueError:
        return False
    signed = f"{ts}:".encode("utf-8") + raw_body
    digest = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return any(hmac.compare_digest(digest, h1) for h1 in h1_values)


async def handle_webhook(
    db: AsyncSession,
    *,
    raw_body: bytes,
    signature_header: str,
    event: dict[str, Any],
) -> dict[str, str]:
    from app.payments.service import activate_subscription, mark_payment_paid

    settings = get_settings()
    if not verify_paddle_signature(
        raw_body=raw_body,
        signature_header=signature_header,
        secret=settings.paddle_webhook_secret,
    ):
        raise AppError(
            message="Paddle imzo noto'g'ri",
            error_code="SIGNATURE_INVALID",
            status_code=401,
        )

    event_type = str(event.get("event_type") or event.get("eventType") or "")
    data = event.get("data") or {}
    custom = data.get("custom_data") or {}
    payment_id_raw = custom.get("payment_id")
    txn_id = str(data.get("id") or "")

    if event_type in {
        "transaction.completed",
        "transaction.paid",
    }:
        if not payment_id_raw:
            return {"status": "ignored", "reason": "no_payment_id"}
        try:
            payment_id = int(payment_id_raw)
        except (TypeError, ValueError):
            raise AppError(
                message="To'lov topilmadi",
                error_code="PAYMENT_NOT_FOUND",
                status_code=404,
            )

        result = await db.execute(
            select(Payment).where(Payment.id == payment_id).with_for_update()
        )
        payment = result.scalar_one_or_none()
        if payment is None:
            raise AppError(
                message="To'lov topilmadi",
                error_code="PAYMENT_NOT_FOUND",
                status_code=404,
            )

        payment.raw_payload = {**(payment.raw_payload or {}), "paddle_event": event}
        if is_paid(payment.status):
            return {"status": "already_processed"}

        if payment.provider not in {"paddle", "mock"}:
            # Defensive: custom_data must belong to a paddle (or test) payment.
            raise AppError(
                message="To'lov topilmadi",
                error_code="PAYMENT_NOT_FOUND",
                status_code=404,
            )

        user_result = await db.execute(
            select(User)
            .where(User.id == payment.user_id)
            .options(selectinload(User.subscription), selectinload(User.business))
        )
        user = user_result.scalar_one_or_none()
        if user is None:
            raise AppError(
                message="Foydalanuvchi topilmadi",
                error_code="USER_NOT_FOUND",
                status_code=404,
            )

        await mark_payment_paid(
            db,
            payment,
            provider_transaction_id=txn_id or payment.provider_transaction_id,
            raw_event=event,
        )

        if payment.kind == "subscription" and payment.plan and payment.billing_cycle:
            await activate_subscription(
                db,
                user.id,
                plan=payment.plan,
                billing_cycle=payment.billing_cycle,
                auto_renew=True,
            )
        return {"status": "processed"}

    if event_type in {"transaction.payment_failed", "transaction.canceled"}:
        if payment_id_raw:
            try:
                payment_id = int(payment_id_raw)
            except (TypeError, ValueError):
                return {"status": "ignored"}
            payment = await db.get(Payment, payment_id)
            if payment and payment.status == "pending":
                payment.status = (
                    "failed" if "failed" in event_type else "cancelled"
                )
                payment.raw_payload = {
                    **(payment.raw_payload or {}),
                    "paddle_event": event,
                }
                await db.flush()
        return {"status": "failed_recorded"}

    if event_type in {"subscription.canceled", "subscription.updated"}:
        # Sync auto_renew when Paddle manages recurring billing.
        user_id_raw = custom.get("user_id")
        if user_id_raw:
            try:
                uid = int(user_id_raw)
            except (TypeError, ValueError):
                return {"status": "ignored"}
            user_result = await db.execute(
                select(User)
                .where(User.id == uid)
                .options(selectinload(User.subscription))
            )
            user = user_result.scalar_one_or_none()
            if user and user.subscription:
                if event_type == "subscription.canceled":
                    user.subscription.auto_renew = False
                else:
                    status = str((data.get("status") or "")).lower()
                    user.subscription.auto_renew = status in {"active", "trialing"}
                await db.flush()
        return {"status": "subscription_synced"}

    return {"status": "ignored", "event_type": event_type}
