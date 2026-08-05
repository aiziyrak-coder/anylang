from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.auth import PasswordStr, _validate_password
from app.schemas.product import ProductCategory, ProductCurrency
from app.schemas.user import BusinessRole

PartnerAppStatus = Literal["pending", "review", "approved", "rejected"]


class PartnerProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    short_description: str = Field(default="", max_length=120)
    description: str = Field(default="", max_length=2000)
    price: Decimal = Field(default=Decimal("0"), ge=0)
    currency: ProductCurrency = "USD"
    category: ProductCategory = "other"
    moq: str | None = Field(default=None, max_length=120)
    shipping_info: str | None = Field(default=None, max_length=255)
    image_urls: list[str] = Field(default_factory=list, max_length=10)
    video_url: str | None = Field(default=None, max_length=512)

    @field_validator("image_urls")
    @classmethod
    def _clip_images(cls, value: list[str]) -> list[str]:
        out: list[str] = []
        for u in value or []:
            s = str(u or "").strip()
            if s and s.startswith("http") and len(s) <= 512:
                out.append(s)
            if len(out) >= 10:
                break
        return out


class PartnerApplicationSubmitIn(BaseModel):
    email: EmailStr
    password: PasswordStr
    contact_name: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=40)
    source_lang: str | None = Field(default="uz", max_length=8)

    company_name: str = Field(min_length=2, max_length=200)
    country: str = Field(min_length=2, max_length=2)
    business_role: BusinessRole = "manufacturer"
    website: str | None = Field(default=None, max_length=255)
    bio: str | None = Field(default=None, max_length=300)
    description: str | None = Field(default=None, max_length=5000)
    founded_year: int | None = Field(default=None, ge=1800, le=2100)
    moq: str | None = Field(default=None, max_length=120)
    production_capacity: str | None = Field(default=None, max_length=160)
    lead_time: str | None = Field(default=None, max_length=120)
    certificates: list[str] = Field(default_factory=list, max_length=20)
    export_countries: list[str] = Field(default_factory=list, max_length=50)
    payment_methods: list[str] = Field(default_factory=list, max_length=20)
    incoterms: list[str] = Field(default_factory=list, max_length=20)

    logo_url: str | None = Field(default=None, max_length=512)
    factory_image_urls: list[str] = Field(default_factory=list, max_length=12)
    factory_video_url: str | None = Field(default=None, max_length=512)

    products: list[PartnerProductIn] = Field(min_length=1, max_length=50)

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        return _validate_password(value)

    @field_validator("country", "export_countries", mode="before")
    @classmethod
    def _upper_country(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().upper()
        if isinstance(value, list):
            return [str(v).strip().upper()[:2] for v in value if str(v).strip()]
        return value

    @field_validator("factory_image_urls")
    @classmethod
    def _clip_factory(cls, value: list[str]) -> list[str]:
        out: list[str] = []
        for u in value or []:
            s = str(u or "").strip()
            if s and s.startswith("http") and len(s) <= 512:
                out.append(s)
            if len(out) >= 12:
                break
        return out


class PartnerApplicationSubmitOut(BaseModel):
    id: int
    status: str
    message: str


class PartnerDuplicateHit(BaseModel):
    kind: str  # email | phone | company | user_email | user_phone
    matched_id: int | None = None
    matched_type: str  # application | user
    label: str


class PartnerProductOut(BaseModel):
    id: int
    position: int
    name: str
    short_description: str
    description: str
    price: Decimal
    currency: str
    category: str
    moq: str | None = None
    shipping_info: str | None = None
    image_urls: list[str] = Field(default_factory=list)
    video_url: str | None = None


class PartnerApplicationOut(BaseModel):
    id: int
    status: str
    email: str
    contact_name: str
    phone: str | None = None
    company_name: str
    country: str | None = None
    business_role: str | None = None
    website: str | None = None
    bio: str | None = None
    description: str | None = None
    founded_year: int | None = None
    moq: str | None = None
    production_capacity: str | None = None
    lead_time: str | None = None
    certificates: list[str] = Field(default_factory=list)
    export_countries: list[str] = Field(default_factory=list)
    payment_methods: list[str] = Field(default_factory=list)
    incoterms: list[str] = Field(default_factory=list)
    logo_url: str | None = None
    factory_image_urls: list[str] = Field(default_factory=list)
    factory_video_url: str | None = None
    admin_note: str | None = None
    reviewed_at: datetime | None = None
    reviewed_by: int | None = None
    created_user_id: int | None = None
    submitted_at: datetime | None = None
    created_at: datetime | None = None
    products: list[PartnerProductOut] = Field(default_factory=list)
    products_count: int = 0
    duplicates: list[PartnerDuplicateHit] = Field(default_factory=list)
    is_duplicate: bool = False
    gallery_urls: list[str] = Field(default_factory=list)
    onboarding_checklist: list[dict] | None = None
    welcome_email_sent: bool | None = None


class PartnerApplicationListOut(BaseModel):
    items: list[PartnerApplicationOut]
    total: int
    page: int
    limit: int
    has_more: bool = False


class PartnerBoardOut(BaseModel):
    new: list[PartnerApplicationOut] = Field(default_factory=list)
    review: list[PartnerApplicationOut] = Field(default_factory=list)
    approved: list[PartnerApplicationOut] = Field(default_factory=list)
    rejected: list[PartnerApplicationOut] = Field(default_factory=list)
    counts: dict[str, int] = Field(default_factory=dict)


class PartnerAnalyticsOut(BaseModel):
    applications: int
    in_review: int
    approved: int
    rejected: int
    accounts_created: int
    with_first_listing: int
    conversion_account_pct: float
    conversion_listing_pct: float
    days: int


class PartnerDecideIn(BaseModel):
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class PartnerStageIn(BaseModel):
    stage: Literal["pending", "review"]


class PartnerUploadOut(BaseModel):
    url: str
    kind: str  # image | video


class EmailCheckOut(BaseModel):
    available: bool
    message: str
