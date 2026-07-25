from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.user import NetworkingScoreOut


class FriendOut(BaseModel):
    id: int
    full_name: str
    number: str = Field(min_length=7, max_length=7)
    avatar_url: str | None = None
    is_online: bool = False
    last_seen_at: datetime | None = None
    native_language: str
    country: str | None = None
    is_business: bool = False
    verified_badge: bool = False
    company_name: str | None = None
    business_role: str | None = None
    rating: float | None = None
    friends_since: datetime | None = None
    keywords: list[str] = Field(default_factory=list)
    product_categories: list[str] = Field(default_factory=list)
    app_language: str | None = None
    spoken_languages: list[str] = Field(default_factory=list)
    products_count: int = Field(default=0, ge=0)
    countries_count: int = Field(default=0, ge=0)


class FriendListOut(BaseModel):
    items: list[FriendOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool
    online_count: int = Field(ge=0)
    pending_incoming_count: int = Field(ge=0)
    networking: NetworkingScoreOut | None = None


class FriendRequestCreateIn(BaseModel):
    user_id: int


class FriendRequestOut(BaseModel):
    id: int
    user_id: int
    status: str
    created_at: datetime
    auto_accepted: bool = False


class FriendRequestAcceptOut(BaseModel):
    id: int
    status: str
    friend: FriendOut


class FriendRequestStatusOut(BaseModel):
    id: int
    status: str


class FriendRequestListItemOut(BaseModel):
    id: int
    user: FriendOut
    created_at: datetime
    # pending | none — `none` = rad etilgan (qayta yuborish mumkin); UI da "Qo'shish"
    status: str = "pending"


class FriendRequestListOut(BaseModel):
    items: list[FriendRequestListItemOut]
    total: int = Field(ge=0)
    has_more: bool


class FriendRemovedOut(BaseModel):
    user_id: int
    status: str
