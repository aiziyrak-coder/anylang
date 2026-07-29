from datetime import date

from pydantic import BaseModel, Field

from app.schemas.user import BusinessRole, NetworkingScoreOut


class UserUpdateIn(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=100)
    birth_date: date | None = None
    gender: str | None = None
    country: str | None = Field(default=None, min_length=2, max_length=2)
    app_language: str | None = None
    native_language: str | None = Field(default=None, min_length=2, max_length=8)
    translation_domain: str | None = Field(default=None, max_length=32)
    email: str | None = None  # ignored — email change is a separate flow


class AvatarOut(BaseModel):
    avatar_url: str


class BusinessUpdateIn(BaseModel):
    company_name: str | None = Field(default=None, max_length=200)
    country: str | None = Field(default=None, min_length=2, max_length=2)
    business_role: BusinessRole | None = None
    website: str | None = Field(default=None, max_length=255)
    bio: str | None = Field(default=None, max_length=300)
    description: str | None = None
    seo_text: str | None = None
    keywords: list[str] | None = None
    description_i18n: dict[str, str] | None = None
    founded_year: int | None = Field(default=None, ge=1800, le=2100)
    certificates: list[str] | None = None
    export_countries: list[str] | None = None
    moq: str | None = Field(default=None, max_length=120)
    production_capacity: str | None = Field(default=None, max_length=160)
    lead_time: str | None = Field(default=None, max_length=120)
    incoterms: list[str] | None = None
    payment_methods: list[str] | None = None


class AiCompanyProfileIn(BaseModel):
    prompt: str = Field(min_length=8, max_length=2000)
    company_name: str | None = Field(default=None, max_length=200)
    country: str | None = Field(default=None, max_length=2)
    business_role: BusinessRole | None = None
    locale: str = Field(default="uz", max_length=16)


class AiCompanyProfileLangOut(BaseModel):
    code: str
    name: str


class AiCompanyProfileOut(BaseModel):
    description: str
    seo_text: str
    keywords: list[str] = Field(default_factory=list)
    translations: dict[str, str] = Field(default_factory=dict)
    languages: list[AiCompanyProfileLangOut] = Field(default_factory=list)


class LogoOut(BaseModel):
    logo_url: str


class FactoryImageCreateOut(BaseModel):
    id: int
    url: str


class PublicBusinessOut(BaseModel):
    business_role: BusinessRole | None = None
    founded_year: int | None = None
    website: str | None = None
    bio: str | None = None
    description: str | None = None
    seo_text: str | None = None
    keywords: list[str] = Field(default_factory=list)
    description_i18n: dict[str, str] = Field(default_factory=dict)
    completeness: int = Field(ge=0, le=100, default=0)
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
    factory_verification: dict | None = None
    trust_score: dict | None = None
    scam_risk: dict | None = None
    factory_images: list[dict] = Field(default_factory=list)
    stats: dict = Field(default_factory=dict)


class PublicUserProfileOut(BaseModel):
    id: int
    is_business: bool
    name: str
    verified_badge: bool
    country: str | None = None
    subtitle_role: str
    number: str
    avatar_url: str | None = None
    business: PublicBusinessOut | None = None
    business_card_url: str | None = None
    friendship_status: str = "none"
    friendship_request_id: int | None = None
    is_request_incoming: bool = False
    networking: NetworkingScoreOut | None = None


class UserSearchItemOut(BaseModel):
    id: int
    full_name: str
    number: str
    avatar_url: str | None = None
    is_online: bool = False
    last_seen_at: str | None = None
    native_language: str
    country: str | None = None
    is_business: bool
    verified_badge: bool
    company_name: str | None = None
    business_role: str | None = None
    rating: float | None = None
    friendship_status: str
    friendship_request_id: int | None = None
    is_request_incoming: bool = False


class UserSearchOut(BaseModel):
    items: list[UserSearchItemOut]
    page: int
    limit: int
    total: int
    has_more: bool
