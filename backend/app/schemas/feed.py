from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

FeedPostType = Literal[
    "new_product",
    "new_factory",
    "new_certificate",
    "exhibition",
    "discount",
]


class FeedAuthorOut(BaseModel):
    id: int
    company_name: str
    logo_url: str | None = None
    verified_badge: bool = False
    factory_verified: bool = False
    country: str | None = None


class FeedPostOut(BaseModel):
    id: int
    post_type: FeedPostType
    title: str
    body: str = ""
    image_url: str | None = None
    meta: dict = Field(default_factory=dict)
    created_at: datetime
    author: FeedAuthorOut
    is_mine: bool = False


class FeedListOut(BaseModel):
    items: list[FeedPostOut]
    page: int
    limit: int
    total: int
    has_more: bool


class FeedPostCreateIn(BaseModel):
    post_type: FeedPostType
    title: str = Field(min_length=2, max_length=160)
    body: str = Field(default="", max_length=800)
    image_url: str | None = Field(default=None, max_length=512)
    meta: dict = Field(default_factory=dict)
