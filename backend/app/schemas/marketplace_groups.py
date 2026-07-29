from __future__ import annotations

from pydantic import BaseModel, Field


class MarketplaceGroupOut(BaseModel):
    id: int
    slug: str
    emoji: str = "🏪"
    title: str
    blurb: str = ""
    member_count: int = 0
    joined: bool = False
    rfq_today: int = 0
    my_role: str | None = None
    verified_only: bool = False
    can_join: bool = True


class MarketplaceGroupListOut(BaseModel):
    items: list[MarketplaceGroupOut] = Field(default_factory=list)
    viewer_verified: bool = False


class MarketplaceMemberPreviewOut(BaseModel):
    user_id: int
    full_name: str
    avatar_url: str | None = None
    is_online: bool = False
    verified_badge: bool = False
    role: str | None = None


class MarketplaceGroupPreviewOut(BaseModel):
    id: int
    slug: str
    emoji: str = "🏪"
    title: str
    blurb: str = ""
    member_count: int = 0
    rfq_today: int = 0
    verified_only: bool = True
    joined: bool = False
    can_join: bool = False
    viewer_verified: bool = False
    trust_score: int = Field(ge=0, le=100, default=0)
    trust_level: str = "low"
    documents_verified: bool = False
    members: list[MarketplaceMemberPreviewOut] = Field(default_factory=list)
    members_shown: int = 0
