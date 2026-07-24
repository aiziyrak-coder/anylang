from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.user import BillingCycle, SubscriptionPlan, UserOut

PaymentKind = Literal["subscription", "number", "super_group"]
PaymentStatus = Literal["pending", "succeeded", "failed", "canceled"]
PaymentProvider = Literal["mock", "stripe"]


class CheckoutIn(BaseModel):
    kind: PaymentKind
    plan: SubscriptionPlan | None = None
    billing_cycle: BillingCycle | None = None
    number: str | None = Field(default=None, min_length=7, max_length=7)
    chat_id: int | None = None


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
