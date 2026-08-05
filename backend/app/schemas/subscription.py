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
    tax: str | None = None
    tax_percent: int | None = None
    total_with_tax: str | None = None
    savings_percent: int | None = None
    currency: str | None = None
    amount_usd: str | None = None


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
    currency: str = "UZS"
    badge: str | None = None
    features: list[PlanFeatureOut]
    periods: list[PlanPeriodOut] = Field(default_factory=list)
    selected_period: PlanPeriodOut | None = None


class PaymentMethodOut(BaseModel):
    code: str
    currency: str
    available: bool = False
    for_countries: list[str] | None = None


class PlansOut(BaseModel):
    plans: list[PlanOut]
    currency: str = "UZS"
    payment_tax_percent: int = 2
    period_options: list[PeriodOptionOut] = Field(default_factory=list)
    usd_uzs_rate: str | None = None
    fx_example_uzs: str | None = None
    fx_source: str | None = None
    fx_date: str | None = None
    user_country: str | None = None
    default_currency: str | None = None
    payment_methods: list[PaymentMethodOut] = Field(default_factory=list)


class SubscribeIn(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
