"""USD ↔ UZS conversion for Click checkout amounts."""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

from app.core.config import get_settings
from app.core.errors import AppError


def usd_to_uzs(amount_usd: Decimal) -> Decimal:
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
    # Click amounts are typically whole soms (or 2 decimals).
    return (amount_usd * rate).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
