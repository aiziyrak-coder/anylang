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
