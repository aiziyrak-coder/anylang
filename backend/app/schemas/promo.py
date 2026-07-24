from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

DiscountType = Literal["percent", "fixed"]


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
