from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

DiscountType = Literal["percent", "fixed"]
CodeType = Literal["standard", "campaign", "referral", "influencer"]
Segment = Literal["all", "new_users"]
Variant = Literal["A", "B"]


class PromoOut(BaseModel):
    id: int
    code: str
    description: str | None = None
    discount_type: DiscountType
    discount_value: str
    applies_to_plans: list[str] | None = None
    min_months: int | None = None
    max_uses: int | None = None
    used_count: int
    max_uses_per_user: int
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool
    is_paused: bool = False
    campaign_key: str | None = None
    variant: str | None = None
    code_type: CodeType = "standard"
    segment: Segment = "all"
    new_user_max_age_days: int = 7
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None
    influencer_label: str | None = None
    status: str | None = None
    created_at: datetime
    updated_at: datetime


class PromoCreateIn(BaseModel):
    code: str = Field(min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: DiscountType = "percent"
    discount_value: Decimal = Field(gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int = Field(default=1, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool = True
    is_paused: bool = False
    campaign_key: str | None = Field(default=None, max_length=64)
    variant: Variant | None = None
    code_type: CodeType = "standard"
    segment: Segment = "all"
    new_user_max_age_days: int = Field(default=7, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None
    influencer_label: str | None = Field(default=None, max_length=120)


class PromoUpdateIn(BaseModel):
    code: str | None = Field(default=None, min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: DiscountType | None = None
    discount_value: Decimal | None = Field(default=None, gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int | None = Field(default=None, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None
    is_paused: bool | None = None
    campaign_key: str | None = Field(default=None, max_length=64)
    variant: Variant | None = None
    code_type: CodeType | None = None
    segment: Segment | None = None
    new_user_max_age_days: int | None = Field(default=None, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None
    influencer_label: str | None = Field(default=None, max_length=120)


class PromoCampaignCreateIn(BaseModel):
    campaign_key: str | None = Field(default=None, max_length=64)
    code_a: str = Field(min_length=3, max_length=64)
    code_b: str = Field(min_length=3, max_length=64)
    description: str | None = Field(default=None, max_length=2000)
    discount_type: DiscountType = "percent"
    discount_value_a: Decimal = Field(gt=0)
    discount_value_b: Decimal = Field(gt=0)
    applies_to_plans: list[str] | None = None
    min_months: int | None = Field(default=None, ge=1, le=12)
    max_uses: int | None = Field(default=None, ge=1)
    max_uses_per_user: int = Field(default=1, ge=1, le=100)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    segment: Segment = "all"
    new_user_max_age_days: int = Field(default=7, ge=1, le=90)
    allowed_countries: list[str] | None = None
    allowed_languages: list[str] | None = None


class PromoValidateIn(BaseModel):
    code: str = Field(min_length=3, max_length=64)
    plan: str
    billing_cycle: str


class PromoValidateOut(BaseModel):
    promo_id: int
    code: str
    discount_type: DiscountType
    discount_value: str
    amount_before: str
    discount_amount: str
    amount_after: str
    currency: str = "USD"
