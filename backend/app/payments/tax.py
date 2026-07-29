"""Payment processing tax (merchant fee passed to payer).

Currently 2% is added on top of the catalog / base amount so the charged
total ("itogo") includes the tax and the user sees it before checkout.
"""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

PAYMENT_TAX_RATE = Decimal("0.02")
PAYMENT_TAX_PERCENT = 2


def apply_payment_tax(
    amount: Decimal,
    *,
    whole: bool = False,
) -> tuple[Decimal, Decimal, Decimal]:
    """Return (base, tax, total) where total = base + 2% tax.

    `whole=True` quantizes to integer currency units (UZS soms).
    """
    quantum = Decimal("1") if whole else Decimal("0.01")
    base = amount.quantize(quantum, rounding=ROUND_HALF_UP)
    tax = (base * PAYMENT_TAX_RATE).quantize(quantum, rounding=ROUND_HALF_UP)
    total = (base + tax).quantize(quantum, rounding=ROUND_HALF_UP)
    return base, tax, total


def tax_meta(base: Decimal, tax: Decimal, total: Decimal) -> dict[str, str | int]:
    return {
        "tax_percent": PAYMENT_TAX_PERCENT,
        "amount_before_tax": f"{base}",
        "tax_amount": f"{tax}",
        "amount_with_tax": f"{total}",
    }
