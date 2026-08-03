"""Payment webhook / checkout schemas (Click + Paddle)."""

from __future__ import annotations

from typing import Literal, Self

from pydantic import BaseModel, Field, model_validator

from app.schemas.user import BillingCycle, SubscriptionPlan

CheckoutProvider = Literal["click", "paddle", "multicard"]


class SubscriptionCheckoutIn(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
    provider: CheckoutProvider = Field(
        default="click",
        description="Live: click (UZS). paddle/multicard accepted but remapped to click until wired.",
    )


class SubscriptionCheckoutOut(BaseModel):
    payment_id: int
    id: int | None = None  # Flutter legacy alias (== payment_id)
    provider: CheckoutProvider
    checkout_url: str
    amount: str
    currency: str
    status: str = "pending"
    mock_confirm: bool = False
    amount_before_tax: str | None = None
    tax_amount: str | None = None
    tax_percent: int | None = None

    @model_validator(mode="after")
    def _sync_id(self) -> Self:
        if self.id is None:
            self.id = self.payment_id
        return self
