from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

MessageType = Literal[
    "text",
    "image",
    "video",
    "audio",
    "file",
    "voice",
    "product",
    "location",
    "contact",
    "system",
]


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
    type: Literal["direct", "group"] = "direct"
    title: str | None = None
    avatar_url: str | None = None
    interlocutor: InterlocutorOut | None = None
    participant_count: int = 0
    last_message: LastMessagePreviewOut | None = None
    unread_count: int = Field(ge=0, default=0)
    last_message_at: datetime | None = None
    muted: bool = False
    pinned: bool = False
    my_role: str | None = None
    is_super: bool = False
    created_by: int | None = None
    invite_link: str | None = None
    member_limit: int | None = None


class ChatListOut(BaseModel):
    items: list[ChatOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool


class ChatCreateIn(BaseModel):
    user_id: int


class GroupCreateIn(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    user_ids: list[int] = Field(min_length=1, max_length=99)


class GroupUpdateIn(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)


class GroupMembersAddIn(BaseModel):
    user_ids: list[int] = Field(min_length=1, max_length=99)


class TransferOwnershipIn(BaseModel):
    user_id: int


class MemberOut(BaseModel):
    user_id: int
    role: str
    full_name: str
    avatar_url: str | None = None
    is_online: bool = False
    number: str | None = None


class MembersOut(BaseModel):
    items: list[MemberOut]
    total: int = 0
    added: int | None = None


class InviteOut(BaseModel):
    token: str | None = None
    link: str | None = None
    enabled: bool = True


class InvitePreviewOut(BaseModel):
    token: str
    title: str
    avatar_url: str | None = None
    member_count: int = 0
    is_member: bool = False
    is_super: bool = False
    chat_id: int | None = None
    invite_link: str | None = None


class ChatSearchItemOut(BaseModel):
    id: int
    type: Literal["direct", "group"] = "direct"
    title: str | None = None
    interlocutor: InterlocutorOut | None = None
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
    sender_name: str | None = None
    sender_avatar_url: str | None = None
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
    edited_at: datetime | None = None
    reactions: list[dict[str, Any]] = Field(default_factory=list)
    pinned: bool = False


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


class MessageEditIn(BaseModel):
    text: str = Field(min_length=1, max_length=8000)


class MessageForwardIn(BaseModel):
    chat_ids: list[int] = Field(min_length=1, max_length=20)
    hide_sender: bool = False


class ReactionIn(BaseModel):
    emoji: str = Field(min_length=1, max_length=8)


class ClearHistoryIn(BaseModel):
    for_everyone: bool = False


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
