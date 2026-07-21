from datetime import date

from pydantic import BaseModel, Field

from app.schemas.user import BusinessRole


class UserUpdateIn(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=100)
    birth_date: date | None = None
    gender: str | None = None
    country: str | None = Field(default=None, min_length=2, max_length=2)
    app_language: str | None = None
    native_language: str | None = Field(default=None, min_length=2, max_length=8)
    email: str | None = None  # ignored — email change is a separate flow


class AvatarOut(BaseModel):
    avatar_url: str


class BusinessUpdateIn(BaseModel):
    company_name: str | None = Field(default=None, max_length=200)
    country: str | None = Field(default=None, min_length=2, max_length=2)
    business_role: BusinessRole | None = None
    website: str | None = Field(default=None, max_length=255)
    description: str | None = None
    founded_year: int | None = Field(default=None, ge=1800, le=2100)
    certificates: list[str] | None = None


class LogoOut(BaseModel):
    logo_url: str


class FactoryImageCreateOut(BaseModel):
    id: int
    url: str


class PublicBusinessOut(BaseModel):
    business_role: BusinessRole | None = None
    founded_year: int | None = None
    website: str | None = None
    completeness: int = Field(ge=0, le=100, default=0)
    certificates: list[str] = Field(default_factory=list)
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
    friendship_status: str
    friendship_request_id: int | None = None
    is_request_incoming: bool = False


class UserSearchOut(BaseModel):
    items: list[UserSearchItemOut]
    page: int
    limit: int
    total: int
    has_more: bool
