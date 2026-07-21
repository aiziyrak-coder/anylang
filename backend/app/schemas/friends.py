from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


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
    friends_since: datetime | None = None


class FriendListOut(BaseModel):
    items: list[FriendOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool
    online_count: int = Field(ge=0)
    pending_incoming_count: int = Field(ge=0)


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


class FriendRequestListOut(BaseModel):
    items: list[FriendRequestListItemOut]
    total: int = Field(ge=0)
    has_more: bool


class FriendRemovedOut(BaseModel):
    user_id: int
    status: str
