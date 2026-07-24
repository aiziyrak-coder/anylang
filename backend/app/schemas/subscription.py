from pydantic import BaseModel, Field

from app.schemas.user import BillingCycle, SubscriptionPlan


class PlanFeatureOut(BaseModel):
    text: str
    included: bool


class PlanPeriodOut(BaseModel):
    months: int
    code: str
    total: str
    per_month: str
    savings_percent: int | None = None


class PeriodOptionOut(BaseModel):
    months: int
    code: str
    discount_percent: int


class PlanOut(BaseModel):
    code: SubscriptionPlan
    title: str
    is_free: bool
    monthly_price: str | None = None
    yearly_price: str | None = None
    # Yearly billed total = yearly_price (monthly-equivalent) * 12
    yearly_total: str | None = None
    savings_percent: int | None = None
    currency: str = "USD"
    badge: str | None = None
    features: list[PlanFeatureOut]
    periods: list[PlanPeriodOut] = Field(default_factory=list)
    selected_period: PlanPeriodOut | None = None


class PlansOut(BaseModel):
    plans: list[PlanOut]
    period_options: list[PeriodOptionOut] = Field(default_factory=list)


class SubscribeIn(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
