"""Multicard / Rahmat Pay — hosted checkout (card, Payme, Click, Uzum, Visa/MC).

Docs: https://docs.multicard.uz/
Sandbox: https://dev-mesh.multicard.uz/
Amount unit: tiyin (1 UZS = 100 tiyin).
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.models.payment import Payment
from app.payments.base import PaymentProvider, amount_str, is_paid
from app.payments.service import mark_payment_paid

logger = logging.getLogger(__name__)

# Token cache (process-local). Multicard tokens last ~24h.
_token_cache: dict[str, tuple[str, float]] = {}


def uzs_to_tiyin(amount_uzs: Decimal) -> int:
    """Whole soms → tiyin integer for Multicard API."""
    soms = amount_uzs.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return int(soms * 100)


def tiyin_to_uzs(amount_tiyin: int | str | float) -> Decimal:
    return (Decimal(str(amount_tiyin)) / Decimal("100")).quantize(Decimal("0.01"))


class MulticardProvider(PaymentProvider):
    name = "multicard"

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def is_configured(self) -> bool:
        s = self.settings
        return bool(
            s.multicard_application_id
            and s.multicard_secret
            and s.multicard_store_id > 0
            and s.multicard_base_url
        )

    def _cache_key(self) -> str:
        s = self.settings
        return f"{s.multicard_base_url}|{s.multicard_application_id}"

    async def _get_token(self, client: httpx.AsyncClient) -> str:
        key = self._cache_key()
        cached = _token_cache.get(key)
        now = time.time()
        # Refresh 1h before expiry (token ~24h).
        if cached and cached[1] > now + 3600:
            return cached[0]

        s = self.settings
        resp = await client.post(
            "/auth",
            json={
                "application_id": s.multicard_application_id,
                "secret": s.multicard_secret,
            },
        )
        if resp.status_code >= 400:
            logger.error("Multicard auth failed: %s %s", resp.status_code, resp.text[:500])
            raise AppError(
                message="Multicard autentifikatsiya xatosi",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
        data = resp.json()
        token = data.get("token") or (data.get("data") or {}).get("token")
        if not token:
            raise AppError(
                message="Multicard token olinmadi",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
        # Prefer API expiry if present; else 20h.
        expiry = now + 20 * 3600
        _token_cache[key] = (str(token), expiry)
        return str(token)

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        s = self.settings
        base = s.multicard_base_url.rstrip("/")
        async with httpx.AsyncClient(base_url=base, timeout=30.0) as client:
            token = await self._get_token(client)
            headers = {
                "Authorization": f"Bearer {token}",
                "X-Access-Token": token,
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
            resp = await client.request(method, path, json=json_body, headers=headers)
            if resp.status_code == 401:
                _token_cache.pop(self._cache_key(), None)
                token = await self._get_token(client)
                headers["Authorization"] = f"Bearer {token}"
                headers["X-Access-Token"] = token
                resp = await client.request(method, path, json=json_body, headers=headers)
            try:
                payload = resp.json()
            except Exception:
                payload = {"raw": resp.text[:1000]}
            if resp.status_code >= 400 or (
                isinstance(payload, dict) and payload.get("success") is False
            ):
                details = ""
                if isinstance(payload, dict):
                    err = payload.get("error") or {}
                    details = str(err.get("details") or err.get("code") or payload)
                logger.error(
                    "Multicard %s %s failed: %s %s",
                    method,
                    path,
                    resp.status_code,
                    details or resp.text[:400],
                )
                raise AppError(
                    message="Multicard so‘rovi muvaffaqiyatsiz",
                    error_code="PAYMENT_PROVIDER_ERROR",
                    status_code=502,
                    extra={"details": details[:300]},
                )
            return payload if isinstance(payload, dict) else {"data": payload}

    async def create_checkout(self, payment: Payment) -> dict[str, Any]:
        if not self.is_configured():
            raise AppError(
                message="Multicard to‘lov sozlanmagan",
                error_code="PAYMENT_UNAVAILABLE",
                status_code=503,
            )
        s = self.settings
        # Our Payment.amount for multicard is stored in UZS soms.
        amount_tiyin = uzs_to_tiyin(Decimal(payment.amount))
        if amount_tiyin < 10000:  # min 100 so'm
            raise AppError(
                message="To‘lov summasi juda kichik (min 100 so‘m)",
                error_code="PAYMENT_INVALID",
                status_code=400,
            )

        invoice_id = f"al-{payment.id}"
        public = s.public_api_base_url.rstrip("/")
        callback_url = f"{public}/api/v1/payments/multicard/callback"
        return_url = f"{public}/billing/success"

        body = {
            "store_id": int(s.multicard_store_id),
            "amount": amount_tiyin,
            "invoice_id": invoice_id,
            "callback_url": callback_url,
            "return_url": return_url,
        }
        raw = await self._request("POST", "/payment/invoice", json_body=body)
        data = raw.get("data") if isinstance(raw.get("data"), dict) else raw
        uuid = str(data.get("uuid") or "")
        checkout_url = (
            data.get("checkout_url")
            or data.get("short_link")
            or (f"https://dev-app.rhmt.uz/invoice/{uuid}" if uuid else "")
        )
        if not checkout_url:
            raise AppError(
                message="Multicard checkout URL qaytmadi",
                error_code="PAYMENT_PROVIDER_ERROR",
                status_code=502,
            )

        payment.provider_transaction_id = uuid or None
        meta = dict(payment.meta or {})
        meta.update(
            {
                "multicard_uuid": uuid,
                "multicard_invoice_id": invoice_id,
                "amount_tiyin": amount_tiyin,
                "checkout_url": checkout_url,
                "short_link": data.get("short_link"),
            }
        )
        payment.meta = meta
        payment.raw_payload = {
            **(payment.raw_payload or {}),
            "invoice_create": raw,
        }

        return {
            "payment_id": payment.id,
            "id": payment.id,
            "provider": self.name,
            "checkout_url": str(checkout_url),
            "amount": amount_str(payment.amount),
            "currency": payment.currency,
            "status": payment.status,
            "mock_confirm": False,
        }

    async def fetch_invoice(self, uuid: str) -> dict[str, Any]:
        raw = await self._request("GET", f"/payment/invoice/{uuid}")
        data = raw.get("data") if isinstance(raw.get("data"), dict) else raw
        return data if isinstance(data, dict) else {}


def _norm_amount_for_sign(amount: Any) -> str:
    """Multicard may send 50000 / 50000.0 / 50000.00 — sign uses integer form."""
    s = str(amount).strip()
    if "." in s:
        s = s.split(".", 1)[0]
    return s


def verify_callback_sign(payload: dict[str, Any], *, secret: str) -> bool:
    """Accept both documented schemes:

    - webhooks: sha1(uuid + invoice_id + amount + secret)
    - success:  md5(store_id + invoice_id + amount + secret)
    """
    received = str(payload.get("sign") or payload.get("signature") or "").strip().lower()
    if not received or not secret:
        return False

    uuid = str(payload.get("uuid") or "")
    invoice_id = str(payload.get("invoice_id") or payload.get("store_invoice_id") or "")
    amount = _norm_amount_for_sign(payload.get("amount") or payload.get("payment_amount") or "")
    store_id = str(payload.get("store_id") or "")

    candidates = [
        hashlib.sha1(f"{uuid}{invoice_id}{amount}{secret}".encode()).hexdigest(),
        hashlib.md5(f"{store_id}{invoice_id}{amount}{secret}".encode()).hexdigest(),
        # Some payloads omit store_id / use payment uuid only.
        hashlib.sha1(f"{uuid}{invoice_id}{amount}{secret}".encode()).hexdigest().upper(),
        hashlib.md5(f"{store_id}{invoice_id}{amount}{secret}".encode()).hexdigest().upper(),
    ]
    for expected in candidates:
        if hmac.compare_digest(expected.lower(), received.lower()):
            return True
    return False


def _status_of(payload: dict[str, Any]) -> str:
    status = payload.get("status")
    if not status and isinstance(payload.get("payment"), dict):
        status = payload["payment"].get("status")
    return str(status or "").strip().lower()


async def handle_callback(
    db: AsyncSession,
    payload: dict[str, Any],
    *,
    settings: Settings | None = None,
    require_sign: bool = True,
) -> dict[str, str]:
    """Process Multicard invoice/payment webhook."""
    s = settings or get_settings()
    if not s.multicard_secret:
        raise AppError(
            message="Multicard sozlanmagan",
            error_code="PAYMENT_UNAVAILABLE",
            status_code=503,
        )

    if require_sign:
        if not (payload.get("sign") or payload.get("signature")):
            raise AppError(
                message="Multicard imzo yo‘q",
                error_code="PAYMENT_SIGN_INVALID",
                status_code=401,
            )
        if not verify_callback_sign(payload, secret=s.multicard_secret):
            logger.warning("Multicard callback bad sign: %s", payload)
            raise AppError(
                message="Multicard imzo noto‘g‘ri",
                error_code="PAYMENT_SIGN_INVALID",
                status_code=401,
            )

    status = _status_of(payload)
    invoice_id = str(payload.get("invoice_id") or payload.get("store_invoice_id") or "")
    uuid = str(payload.get("uuid") or "")

    payment = await _find_payment(db, invoice_id=invoice_id, uuid=uuid)
    if payment is None:
        logger.warning(
            "Multicard callback unknown payment invoice=%s uuid=%s",
            invoice_id,
            uuid,
        )
        return {"status": "ignored"}

    payment.raw_payload = {
        **(payment.raw_payload or {}),
        "callback": payload,
        "callback_status": status,
    }

    if status in {"draft", "progress", "pending", ""}:
        await db.flush()
        return {"status": "ok"}

    if status in {"error", "failed", "canceled", "cancelled"}:
        if not is_paid(payment.status):
            payment.status = "failed"
        await db.flush()
        return {"status": "ok"}

    if status in {"revert", "refund", "refunded"}:
        if is_paid(payment.status):
            payment.status = "refunded"
        await db.flush()
        return {"status": "ok"}

    if status != "success":
        logger.info("Multicard callback unhandled status=%s", status)
        await db.flush()
        return {"status": "ok"}

    amount_raw = payload.get("amount") or payload.get("payment_amount")
    if amount_raw is not None:
        expected_tiyin = uzs_to_tiyin(Decimal(payment.amount))
        got = int(_norm_amount_for_sign(amount_raw) or "0")
        if got != expected_tiyin:
            logger.error(
                "Multicard amount mismatch payment=%s expected=%s got=%s",
                payment.id,
                expected_tiyin,
                got,
            )
            raise AppError(
                message="To‘lov summasi mos kelmadi",
                error_code="PAYMENT_AMOUNT_MISMATCH",
                status_code=400,
            )

    already = is_paid(payment.status)
    await mark_payment_paid(
        db,
        payment,
        provider_transaction_id=uuid or payment.provider_transaction_id,
        raw_event=payload,
    )

    if not already:
        from app.services.payments import apply_payment

        await apply_payment(db, payment)

    await db.flush()
    return {"status": "ok"}


async def _find_payment(
    db: AsyncSession,
    *,
    invoice_id: str,
    uuid: str,
) -> Payment | None:
    if uuid:
        result = await db.execute(
            select(Payment).where(Payment.provider_transaction_id == uuid).limit(1)
        )
        found = result.scalar_one_or_none()
        if found is not None:
            return found

    if invoice_id.startswith("al-"):
        raw_id = invoice_id[3:]
        if raw_id.isdigit():
            return await db.get(Payment, int(raw_id))

    if invoice_id.isdigit():
        return await db.get(Payment, int(invoice_id))

    result = await db.execute(
        select(Payment)
        .where(Payment.provider == "multicard")
        .order_by(Payment.id.desc())
        .limit(50)
    )
    for p in result.scalars().all():
        meta = p.meta or {}
        if meta.get("multicard_invoice_id") == invoice_id:
            return p
        if uuid and meta.get("multicard_uuid") == uuid:
            return p
    return None


async def sync_payment_status(db: AsyncSession, payment: Payment) -> Payment:
    """Poll Multicard invoice status (authenticated client poll fallback)."""
    if is_paid(payment.status):
        return payment
    uuid = payment.provider_transaction_id or (payment.meta or {}).get("multicard_uuid")
    if not uuid:
        return payment
    provider = MulticardProvider()
    if not provider.is_configured():
        return payment
    try:
        data = await provider.fetch_invoice(str(uuid))
    except AppError:
        return payment
    status = _status_of(data)
    if status != "success":
        return payment
    invoice_id = (payment.meta or {}).get("multicard_invoice_id") or f"al-{payment.id}"
    amount_tiyin = (payment.meta or {}).get("amount_tiyin") or uzs_to_tiyin(
        Decimal(payment.amount)
    )
    await handle_callback(
        db,
        {
            "uuid": str(uuid),
            "invoice_id": invoice_id,
            "amount": amount_tiyin,
            "status": "success",
            "store_id": get_settings().multicard_store_id,
            "payment": data.get("payment") if isinstance(data.get("payment"), dict) else data,
        },
        require_sign=False,
    )
    await db.refresh(payment)
    return payment
