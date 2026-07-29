from typing import Literal

from pydantic import BaseModel, Field, model_validator

from app.schemas.user import BillingCycle, SubscriptionPlan, UserOut

PaymentKind = Literal["subscription", "number", "super_group", "product_top", "account_slot"]
PaymentStatus = Literal[
    "pending",
    "paid",
    "succeeded",
    "failed",
    "canceled",
    "cancelled",
    "refunded",
]
PaymentProvider = Literal["mock", "stripe", "click", "paddle", "multicard"]


class CheckoutIn(BaseModel):
    kind: PaymentKind
    plan: SubscriptionPlan | None = None
    billing_cycle: BillingCycle | None = None
    promo_code: str | None = Field(default=None, min_length=3, max_length=64)
    number: str | None = Field(default=None, min_length=7, max_length=7)
    chat_id: int | None = None
    # Paid product TOP boost ($5 / 30 days).
    product_id: int | None = Field(default=None, ge=1)
    # Optional: when set, subscription checkout uses Click/Paddle/Multicard module.
    provider: Literal["click", "paddle", "multicard"] | None = None


class CheckoutOut(BaseModel):
    id: int
    status: PaymentStatus
    provider: PaymentProvider
    amount: str
    currency: str
    kind: PaymentKind
    checkout_url: str | None = None
    stripe_session_id: str | None = None
    client_secret: str | None = None
    mock_confirm: bool = False
    amount_before: str | None = None
    discount_amount: str | None = None
    promo_code: str | None = None


class PaymentOut(BaseModel):
    id: int
    status: PaymentStatus
    provider: PaymentProvider
    amount: str
    currency: str
    kind: PaymentKind
    plan: str | None = None
    billing_cycle: str | None = None
    number: str | None = None
    paid_at: object | None = None
    created_at: object


class ConfirmPaymentOut(BaseModel):
    payment: PaymentOut
    user: UserOut
