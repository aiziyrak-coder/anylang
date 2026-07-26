"""Shared payment provider protocol."""

from __future__ import annotations

from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Any

from app.models.payment import Payment


class PaymentProvider(ABC):
    """Common interface for Click / Paddle / future providers."""

    name: str

    @abstractmethod
    async def create_checkout(self, payment: Payment) -> dict[str, Any]:
        """Return checkout payload including checkout_url."""

    @abstractmethod
    def is_configured(self) -> bool:
        ...


def paid_statuses() -> frozenset[str]:
    return frozenset({"paid", "succeeded"})


def is_paid(status: str) -> bool:
    return status in paid_statuses()


def amount_str(amount: Decimal) -> str:
    """Click expects amount without unnecessary trailing zeros issues — keep 2 decimals."""
    return f"{amount.quantize(Decimal('0.01'))}"
