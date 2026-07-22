from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

MessageType = Literal["text", "image", "video", "audio", "file", "voice"]


class InterlocutorOut(BaseModel):
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


class LastMessagePreviewOut(BaseModel):
    id: int
    type: MessageType
    text: str | None = None
    meta: dict[str, Any] | None = None
    sender_id: int
    created_at: datetime


class ChatOut(BaseModel):
    id: int
    interlocutor: InterlocutorOut
    last_message: LastMessagePreviewOut | None = None
    unread_count: int = Field(ge=0, default=0)
    last_message_at: datetime | None = None


class ChatListOut(BaseModel):
    items: list[ChatOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool


class ChatCreateIn(BaseModel):
    user_id: int


class ChatSearchItemOut(BaseModel):
    id: int
    interlocutor: InterlocutorOut
    last_message_at: datetime | None = None


class ChatSearchOut(BaseModel):
    items: list[ChatSearchItemOut]


class MessageTranslationOut(BaseModel):
    language: str
    text: str
    status: str


class MessageReplyToOut(BaseModel):
    id: int
    sender_id: int
    sender_name: str
    type: str
    preview_text: str | None = None
    is_deleted: bool = False


class MessageOut(BaseModel):
    id: int
    chat_id: int
    sender_id: int
    client_message_id: str
    type: MessageType
    text: str | None = None
    text_original: str | None = None
    original_language: str | None = None
    meta: dict[str, Any] | None = None
    reply_to_id: int | None = None
    reply_to: MessageReplyToOut | None = None
    status: str
    delivered_at: datetime | None = None
    is_deleted: bool = False
    deleted_for_everyone: bool = False
    translations: list[MessageTranslationOut] = Field(default_factory=list)
    read_by_recipient: bool = False
    created_at: datetime


class MessageListOut(BaseModel):
    items: list[MessageOut]
    has_more: bool


class MessageCreateIn(BaseModel):
    client_message_id: str = Field(min_length=1, max_length=64)
    type: MessageType
    text: str | None = None
    meta: dict[str, Any] | None = None
    reply_to_id: int | None = None
    media_id: int | None = None


class ReadMessagesIn(BaseModel):
    message_ids: list[int] = Field(min_length=1)


class ReadMessagesOut(BaseModel):
    read_count: int = Field(ge=0)
    message_ids: list[int]


class ChatMediaUploadOut(BaseModel):
    id: int
    url: str
    type: str


class MessageDeletedOut(BaseModel):
    id: int
    deleted_for_everyone: bool
