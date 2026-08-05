from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

ReviewStatus = Literal["pending", "approved", "rejected"]
BulkReviewAction = Literal["approve", "reject", "hide", "unhide"]


class BusinessReviewCreateIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    text: str = Field(default="", max_length=1000)


class BusinessReviewReplyIn(BaseModel):
    text: str = Field(min_length=2, max_length=1000)


class BusinessReviewOut(BaseModel):
    id: int
    business_user_id: int
    author_id: int
    author_name: str = ""
    author_avatar_url: str | None = None
    rating: int
    text: str
    status: ReviewStatus
    moderation_note: str = ""
    created_at: datetime
    moderated_at: datetime | None = None
    company_name: str | None = None
    company_reply: str = ""
    company_replied_at: datetime | None = None
    is_hidden: bool = False


class BusinessReviewListOut(BaseModel):
    items: list[BusinessReviewOut]
    page: int
    limit: int
    total: int
    has_more: bool
    average_rating: float | None = None
    reviews_count: int = 0
    rating_distribution: dict | None = None
    my_review: BusinessReviewOut | None = None


class AdminBusinessReviewModerateIn(BaseModel):
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class AdminBusinessReviewHideIn(BaseModel):
    hide: bool = True
    reason: str | None = Field(default=None, max_length=500)


class AdminBusinessReviewBulkIn(BaseModel):
    review_ids: list[int] = Field(min_length=1, max_length=50)
    action: BulkReviewAction
    admin_note: str | None = Field(default=None, max_length=500)
