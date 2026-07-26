"""Payment webhook / checkout schemas (Click + Paddle)."""

from __future__ import annotations

from typing import Literal, Self

from pydantic import BaseModel, Field, model_validator

from app.schemas.user import BillingCycle, SubscriptionPlan

CheckoutProvider = Literal["click", "paddle"]


class SubscriptionCheckoutIn(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
    provider: CheckoutProvider = Field(
        description="click = UZS mahalliy; paddle = USD xalqaro (MoR)"
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

    @model_validator(mode="after")
    def _sync_id(self) -> Self:
        if self.id is None:
            self.id = self.payment_id
        return self
