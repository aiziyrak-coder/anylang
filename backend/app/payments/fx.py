"""USD ↔ UZS conversion for Click checkout amounts.

Display catalog stays in USD; Click charges UZS using the Central Bank
of Uzbekistan (CBU) daily rate, with `settings.usd_uzs_rate` as fallback.
"""

from __future__ import annotations

import logging
import time
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

CBU_USD_URL = "https://cbu.uz/uz/arkhiv-kursov-valyut/json/USD/"
# Cache CBU rate briefly — CB updates once per day.
_CACHE_TTL_SEC = 60 * 60
_rate_cache: dict[str, Any] = {
    "rate": None,
    "source": None,
    "fetched_at": 0.0,
    "date": None,
}


def _settings_rate() -> Decimal:
    settings = get_settings()
    try:
        rate = Decimal(str(settings.usd_uzs_rate).replace(",", "").strip())
    except Exception as exc:
        raise AppError(
            message="USD/UZS kursi sozlanmagan",
            error_code="PAYMENT_INVALID",
            status_code=503,
        ) from exc
    if rate <= 0:
        raise AppError(
            message="USD/UZS kursi noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=503,
        )
    return rate


def get_usd_uzs_rate() -> Decimal:
    """Cached CBU rate if fresh; otherwise fetch (sync) or settings fallback."""
    cached = _rate_cache.get("rate")
    fetched_at = float(_rate_cache.get("fetched_at") or 0)
    if isinstance(cached, Decimal) and cached > 0:
        if time.monotonic() - fetched_at < _CACHE_TTL_SEC:
            return cached
    try:
        with httpx.Client(timeout=5.0, follow_redirects=True) as client:
            resp = client.get(CBU_USD_URL)
            resp.raise_for_status()
            rate, date = _parse_cbu_payload(resp.json())
        _rate_cache["rate"] = rate
        _rate_cache["source"] = "cbu"
        _rate_cache["fetched_at"] = time.monotonic()
        _rate_cache["date"] = date
        return rate
    except Exception as exc:
        logger.warning("CBU sync fetch failed, using settings: %s", exc)
        rate = _settings_rate()
        _rate_cache["rate"] = rate
        _rate_cache["source"] = "settings"
        _rate_cache["fetched_at"] = time.monotonic()
        _rate_cache["date"] = None
        return rate


def rate_meta() -> dict[str, Any]:
    rate = get_usd_uzs_rate()
    return {
        "usd_uzs_rate": f"{rate}",
        "fx_source": _rate_cache.get("source") or "settings",
        "fx_date": _rate_cache.get("date"),
    }


def _parse_cbu_payload(data: Any) -> tuple[Decimal, str | None]:
    row: dict[str, Any] | None = None
    if isinstance(data, list) and data:
        first = data[0]
        if isinstance(first, dict):
            row = first
    elif isinstance(data, dict):
        row = data
    if not row:
        raise ValueError("empty CBU payload")
    rate_raw = str(row.get("Rate") or "").replace(",", "").strip()
    nominal_raw = str(row.get("Nominal") or "1").replace(",", "").strip()
    rate = Decimal(rate_raw)
    nominal = Decimal(nominal_raw or "1")
    if rate <= 0 or nominal <= 0:
        raise ValueError("invalid CBU rate")
    # Rate is UZS per `Nominal` units of foreign currency.
    per_unit = (rate / nominal).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    date = row.get("Date")
    return per_unit, str(date) if date else None


async def ensure_cbu_rate(*, force: bool = False) -> Decimal:
    """Refresh USD→UZS from CBU when cache is stale; fall back to settings."""
    cached = _rate_cache.get("rate")
    fetched_at = float(_rate_cache.get("fetched_at") or 0)
    if (
        not force
        and isinstance(cached, Decimal)
        and cached > 0
        and time.monotonic() - fetched_at < _CACHE_TTL_SEC
    ):
        return cached

    try:
        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            resp = await client.get(CBU_USD_URL)
            resp.raise_for_status()
            rate, date = _parse_cbu_payload(resp.json())
        _rate_cache["rate"] = rate
        _rate_cache["source"] = "cbu"
        _rate_cache["fetched_at"] = time.monotonic()
        _rate_cache["date"] = date
        logger.info("CBU USD/UZS rate=%s date=%s", rate, date)
        return rate
    except Exception as exc:
        logger.warning("CBU rate fetch failed, using settings fallback: %s", exc)
        rate = _settings_rate()
        # Keep a short cache so we don't hammer CBU on every checkout.
        _rate_cache["rate"] = rate
        _rate_cache["source"] = "settings"
        _rate_cache["fetched_at"] = time.monotonic()
        _rate_cache["date"] = None
        return rate


def usd_to_uzs(amount_usd: Decimal, *, rate: Decimal | None = None) -> Decimal:
    resolved = rate if rate is not None else get_usd_uzs_rate()
    if resolved <= 0:
        raise AppError(
            message="USD/UZS kursi noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=503,
        )
    # Click amounts are typically whole soms.
    return (amount_usd * resolved).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
