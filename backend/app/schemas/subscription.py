from pydantic import BaseModel

from app.schemas.user import BillingCycle, SubscriptionPlan


class PlanFeatureOut(BaseModel):
    text: str
    included: bool


class PlanOut(BaseModel):
    code: SubscriptionPlan
    title: str
    is_free: bool
    monthly_price: str | None = None
    yearly_price: str | None = None
    currency: str = "USD"
    badge: str | None = None
    features: list[PlanFeatureOut]


class PlansOut(BaseModel):
    plans: list[PlanOut]


class SubscribeIn(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
