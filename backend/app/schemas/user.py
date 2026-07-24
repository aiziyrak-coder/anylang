from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

AppLanguage = Literal["uz_UZ", "ru_RU", "us_US"]
Gender = Literal["male", "female"]
SubscriptionPlan = Literal["basic", "premium", "business"]
# Canonical: "1"|"3"|"6"|"12". Legacy aliases also accepted: monthly|yearly
BillingCycle = str
SubscriptionSource = Literal["purchase", "number_bonus", "admin"]
BusinessRole = Literal["manufacturer", "distributor", "retail", "service"]


class SubscriptionOut(BaseModel):
    plan: SubscriptionPlan
    billing_cycle: BillingCycle | None = None
    started_at: datetime | None = None
    expires_at: datetime | None = None
    auto_renew: bool
    is_active: bool
    source: SubscriptionSource = "purchase"


class FactoryImageOut(BaseModel):
    id: int
    url: str


class BusinessStatsOut(BaseModel):
    listings_count: int = 0
    total_views: int = 0
    rating: float | None = None
    reviews_count: int = 0


class BusinessOut(BaseModel):
    company_name: str
    logo_url: str | None = None
    country: str | None = None
    business_role: BusinessRole | None = None
    website: str | None = None
    description: str | None = None
    founded_year: int | None = None
    certificates: list[str] = Field(default_factory=list)
    factory_images: list[FactoryImageOut] = Field(default_factory=list)
    completeness: int = Field(ge=0, le=100, default=0)
    stats: BusinessStatsOut = Field(default_factory=BusinessStatsOut)


class UserOut(BaseModel):
    """Full user object — TZ section 4.1."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    number: str = Field(min_length=7, max_length=7)
    email: EmailStr
    birth_date: date | None = None
    gender: Gender | None = None
    country: str | None = Field(default=None, max_length=2)
    avatar_url: str | None = None
    app_language: str
    native_language: str

    is_verified: bool
    verified_badge: bool
    is_active: bool
    profile_completed: bool
    created_at: datetime
    last_number_change_at: datetime | None = None

    subscription: SubscriptionOut
    is_business: bool
    business: BusinessOut | None = None
