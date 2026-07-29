"""Shared checkout pricing helpers (test flat UZS amount, tax)."""

from __future__ import annotations

from decimal import Decimal

from app.core.config import Settings, get_settings
from app.payments.tax import apply_payment_tax, tax_meta


def test_amount_uzs(settings: Settings | None = None) -> Decimal | None:
    """Temporary flat UZS price while payment rails are being activated.

    Set PAYMENT_TEST_AMOUNT_UZS=1000 (or empty to disable).
    """
    s = settings or get_settings()
    raw = (getattr(s, "payment_test_amount_uzs", "") or "").strip()
    if not raw:
        return None
    try:
        value = Decimal(raw)
    except Exception:
        return None
    if value <= 0:
        return None
    return value.quantize(Decimal("1"))


def resolve_uzs_charge(
    catalog_amount: Decimal,
    *,
    settings: Settings | None = None,
    apply_tax: bool = True,
) -> tuple[Decimal, Decimal, Decimal, dict[str, str | int]]:
    """Return (base, tax, total, meta) for a UZS charge.

    When PAYMENT_TEST_AMOUNT_UZS is set, total is forced to that amount
    (tax broken out only for display; charged total stays exact).
    """
    s = settings or get_settings()
    flat = test_amount_uzs(s)
    if flat is not None:
        # Charge exactly N so'm during Click onboarding / smoke tests.
        base, tax, total = flat, Decimal("0"), flat
        meta = {
            **tax_meta(base, tax, total),
            "test_amount_uzs": f"{flat}",
            "catalog_amount_uzs": f"{catalog_amount.quantize(Decimal('1'))}",
        }
        return base, tax, total, meta

    if apply_tax:
        base, tax, total = apply_payment_tax(catalog_amount, whole=True)
    else:
        base = catalog_amount.quantize(Decimal("1"))
        tax = Decimal("0")
        total = base
    return base, tax, total, tax_meta(base, tax, total)
