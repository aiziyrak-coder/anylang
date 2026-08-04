from __future__ import annotations

from pydantic import BaseModel, Field


class ProductLikerOut(BaseModel):
    user_id: int
    name: str
    country: str | None = None
    business_role: str | None = None
    avatar_url: str | None = None
    is_business: bool = False
    product_id: int | None = None
    product_title: str | None = None
    liked_at: str | None = None


class ProductLikersOut(BaseModel):
    total_count: int = Field(default=0, ge=0)
    items: list[ProductLikerOut] = Field(default_factory=list)
