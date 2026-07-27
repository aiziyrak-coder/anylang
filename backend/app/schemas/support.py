from __future__ import annotations

from datetime import UTC, datetime

from pydantic import BaseModel, Field


class SupportHistoryItem(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class SupportChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    history: list[SupportHistoryItem] = Field(default_factory=list, max_length=40)
    locale: str = Field(default="uz", max_length=16)
    session_id: int | None = Field(default=None, ge=1)


class SupportChatOut(BaseModel):
    reply: str
    agent_name: str = "Sofiya"
    session_id: int


class SupportMessageOut(BaseModel):
    id: int
    role: str
    content: str
    created_at: datetime


class SupportSessionOut(BaseModel):
    id: int
    status: str
    locale: str
    rating: int | None = None
    preview: str | None = None
    created_at: datetime
    updated_at: datetime
    closed_at: datetime | None = None
    messages: list[SupportMessageOut] = Field(default_factory=list)


class SupportSessionListOut(BaseModel):
    items: list[SupportSessionOut]


class SupportRateIn(BaseModel):
    rating: int = Field(ge=1, le=5)
