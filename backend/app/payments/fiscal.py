"""Click Merchant API — OFD / fiscalization (submit_items).

Auth: Auth: {merchant_user_id}:{sha1(timestamp + secret_key)}:{timestamp}
Docs: https://docs.click.uz/merchant-api/fiscalization
Amounts in items are tiyins (1 so'm = 100 tiyin).
"""

from __future__ import annotations

import hashlib
import logging
import time
from decimal import Decimal
from typing import Any

import httpx

from app.core.config import Settings, get_settings
from app.models.payment import Payment

logger = logging.getLogger(__name__)


def merchant_auth_header(settings: Settings | None = None) -> str | None:
    s = settings or get_settings()
    user_id = (s.click_merchant_user_id or "").strip()
    secret = (s.click_secret_key or "").strip()
    if not user_id or not secret:
        return None
    ts = str(int(time.time()))
    digest = hashlib.sha1(f"{ts}{secret}".encode("utf-8")).hexdigest()
    return f"{user_id}:{digest}:{ts}"


def _som_to_tiyin(amount: Decimal | str | float) -> int:
    return int((Decimal(str(amount)) * Decimal("100")).quantize(Decimal("1")))


def _item_name(payment: Payment) -> str:
    kind = payment.kind or "payment"
    if kind == "subscription" and payment.plan:
        months = payment.billing_cycle or "1"
        return f"AnyLang {payment.plan} ({months} oy)"
    if kind == "super_group":
        return "AnyLang Super Group"
    if kind == "number":
        return f"AnyLang Number {payment.number or ''}".strip()
    if kind == "account_slot":
        return "AnyLang Account Slot"
    if kind == "product_top":
        return "AnyLang Product Top"
    return "AnyLang Payment"


async def submit_fiscal_items(
    payment: Payment,
    *,
    click_payment_id: str | int | None = None,
    settings: Settings | None = None,
) -> dict[str, Any] | None:
    """POST /v2/merchant/payment/ofd_data/submit_items after successful Complete.

    Uses a single IKPU/SPIC from CLICK_OFD_SPIC. Skips quietly when not configured.
    """
    s = settings or get_settings()
    auth = merchant_auth_header(s)
    spic = (s.click_ofd_spic or "").strip()
    service_id = (s.click_service_id or "").strip()
    if not auth or not spic or not service_id:
        logger.info(
            "Click fiscalization skipped (need CLICK_MERCHANT_USER_ID, "
            "CLICK_SECRET_KEY, CLICK_SERVICE_ID, CLICK_OFD_SPIC)"
        )
        return None

    try:
        payment_id = int(click_payment_id or payment.provider_transaction_id or 0)
    except (TypeError, ValueError):
        payment_id = 0
    if payment_id <= 0:
        logger.warning("Click fiscalization skipped — no click payment_id for %s", payment.id)
        return None

    price_tiyin = _som_to_tiyin(payment.amount)
    item: dict[str, Any] = {
        "Name": _item_name(payment),
        "SPIC": spic,
        "PackageCode": (s.click_ofd_package_code or "").strip() or None,
        "GoodPrice": price_tiyin,
        "Price": price_tiyin,
        "Amount": 1000,  # 1.000 unit in milli-units (Click convention)
        "VAT": 0,
        "VATPercent": 0,
        "Units": int(s.click_ofd_units or 1),
    }
    if not item["PackageCode"]:
        item.pop("PackageCode", None)

    body = {
        "service_id": int(service_id),
        "payment_id": payment_id,
        "items": [item],
        "received_card": price_tiyin,
        "received_cash": 0,
        "received_ecash": 0,
    }
    url = f"{s.click_merchant_api_base.rstrip('/')}/payment/ofd_data/submit_items"
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                url,
                json=body,
                headers={
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                    "Auth": auth,
                },
            )
        data: dict[str, Any]
        try:
            parsed = resp.json()
            data = parsed if isinstance(parsed, dict) else {"raw": parsed}
        except Exception:
            data = {"raw": resp.text[:500]}
        if resp.status_code >= 400:
            logger.warning(
                "Click fiscalization HTTP %s for payment %s: %s",
                resp.status_code,
                payment.id,
                data,
            )
        else:
            logger.info("Click fiscalization ok payment=%s click_id=%s", payment.id, payment_id)
        return {"http_status": resp.status_code, **data}
    except Exception:
        logger.exception("Click fiscalization failed payment=%s", payment.id)
        return None
