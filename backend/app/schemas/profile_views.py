from __future__ import annotations

from pydantic import BaseModel, Field


class ProfileViewerOut(BaseModel):
    user_id: int
    name: str
    country: str | None = None
    business_role: str | None = None
    avatar_url: str | None = None
    is_business: bool = False
    view_count: int = 1
    last_viewed_at: str | None = None


class ProfileViewersOut(BaseModel):
    locked: bool = False
    total_count: int = Field(default=0, ge=0)
    items: list[ProfileViewerOut] = Field(default_factory=list)
