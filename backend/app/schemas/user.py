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
    countries_count: int = 0
    export_countries: list[str] = Field(default_factory=list)
    founded_year: int | None = None
    export_years: int | None = None


class TrustFactorOut(BaseModel):
    key: str
    score: int
    max: int
    count: int | None = None
    premium_count: int | None = None
    avg_minutes: float | None = None
    samples: int | None = None
    manual_count: int | None = None
    invoice_count: int | None = None
    verified_badge: bool | None = None
    documents_verified: bool | None = None
    factory_verified: bool | None = None
    inspection_passed: bool | None = None


class TrustScoreOut(BaseModel):
    score: int = Field(ge=0, le=100)
    level: str
    breakdown: list[TrustFactorOut] = Field(default_factory=list)


class NetworkingScoreOut(BaseModel):
    connections: int = Field(default=0, ge=0)
    countries: int = Field(default=0, ge=0)
    trust: int | None = Field(default=None, ge=0, le=100)


class ScamRiskReasonOut(BaseModel):
    key: str
    label: str
    meta: dict = Field(default_factory=dict)


class ScamRiskOut(BaseModel):
    risk_level: str = "none"  # none|low|medium|high
    risk_score: int = Field(default=0, ge=0, le=100)
    message: str = ""
    reasons: list[ScamRiskReasonOut] = Field(default_factory=list)
    generated_by: str = "rules"
    show_warning: bool = False


class FactoryVerificationOut(BaseModel):
    factory_verified: bool = False
    inspection_passed: bool = False
    iso: bool = False
    ce: bool = False
    fda: bool = False
    audit_report_url: str | None = None
    has_any: bool = False


class BusinessOut(BaseModel):
    company_name: str
    logo_url: str | None = None
    country: str | None = None
    business_role: BusinessRole | None = None
    website: str | None = None
    bio: str | None = None
    description: str | None = None
    seo_text: str | None = None
    keywords: list[str] = Field(default_factory=list)
    description_i18n: dict[str, str] = Field(default_factory=dict)
    founded_year: int | None = None
    certificates: list[str] = Field(default_factory=list)
    export_countries: list[str] = Field(default_factory=list)
    moq: str | None = None
    production_capacity: str | None = None
    lead_time: str | None = None
    incoterms: list[str] = Field(default_factory=list)
    payment_methods: list[str] = Field(default_factory=list)
    successful_deals: int = 0
    complaints_count: int = 0
    documents_verified: bool = False
    verification_status: str = "none"
    factory_verified: bool = False
    inspection_passed: bool = False
    audit_report_url: str | None = None
    factory_verification: FactoryVerificationOut | None = None
    trust_score: TrustScoreOut | None = None
    scam_risk: ScamRiskOut | None = None
    factory_images: list[FactoryImageOut] = Field(default_factory=list)
    completeness: int = Field(ge=0, le=100, default=0)
    stats: BusinessStatsOut = Field(default_factory=BusinessStatsOut)
    business_card_url: str | None = None


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
    spoken_languages: list[str] = Field(default_factory=list)
    translation_domain: str = "general"

    is_verified: bool
    verified_badge: bool
    is_active: bool
    profile_completed: bool
    created_at: datetime
    last_number_change_at: datetime | None = None

    subscription: SubscriptionOut
    is_business: bool
    business: BusinessOut | None = None
    networking: NetworkingScoreOut | None = None
    # Bir qurilmada multi-account: free=3, business=5, +$10 extras → max 10.
    extra_account_slots: int = Field(default=0, ge=0, le=7)
    max_local_accounts: int = Field(default=3, ge=3, le=10)
