from decimal import Decimal

from app.payments.tax import PAYMENT_TAX_PERCENT, apply_payment_tax


def test_apply_payment_tax_usd() -> None:
    base, tax, total = apply_payment_tax(Decimal("4.99"))
    assert base == Decimal("4.99")
    assert tax == Decimal("0.10")
    assert total == Decimal("5.09")
    assert PAYMENT_TAX_PERCENT == 2


def test_apply_payment_tax_uzs_whole() -> None:
    base, tax, total = apply_payment_tax(Decimal("62375"), whole=True)
    assert base == Decimal("62375")
    assert tax == Decimal("1248")  # 1247.5 → 1248
    assert total == Decimal("63623")
