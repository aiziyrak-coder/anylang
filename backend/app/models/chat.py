from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


class Chat(Base, TimestampMixin):
    __tablename__ = "chats"
    __table_args__ = (UniqueConstraint("user_low_id", "user_high_id", name="uq_chat_pair"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_low_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    user_high_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    last_message_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    has_messages: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    messages: Mapped[list[Message]] = relationship(back_populates="chat", cascade="all, delete-orphan")


class Message(Base, TimestampMixin):
    __tablename__ = "messages"
    __table_args__ = (UniqueConstraint("chat_id", "client_message_id", name="uq_client_msg"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    chat_id: Mapped[int] = mapped_column(ForeignKey("chats.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    client_message_id: Mapped[str] = mapped_column(String(64), nullable=False)
    type: Mapped[str] = mapped_column(String(16), nullable=False, default="text")
    text_original: Mapped[str | None] = mapped_column(Text, nullable=True)
    original_language: Mapped[str | None] = mapped_column(String(8), nullable=True)
    meta: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    reply_to_id: Mapped[int | None] = mapped_column(ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="sent", nullable=False)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_for_everyone: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    chat: Mapped[Chat] = relationship(back_populates="messages")
    translations: Mapped[list[MessageTranslation]] = relationship(
        back_populates="message", cascade="all, delete-orphan"
    )
    reads: Mapped[list[MessageRead]] = relationship(back_populates="message", cascade="all, delete-orphan")
    hidden_for: Mapped[list[MessageHide]] = relationship(back_populates="message", cascade="all, delete-orphan")


class MessageTranslation(Base, TimestampMixin):
    __tablename__ = "message_translations"
    __table_args__ = (UniqueConstraint("message_id", "language", name="uq_msg_lang"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("messages.id", ondelete="CASCADE"), index=True)
    language: Mapped[str] = mapped_column(String(8), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="done", nullable=False)

    message: Mapped[Message] = relationship(back_populates="translations")


class MessageRead(Base):
    __tablename__ = "message_reads"
    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_msg_read"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("messages.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    message: Mapped[Message] = relationship(back_populates="reads")


class MessageHide(Base):
    """Soft-delete for recipient only (delete for me)."""

    __tablename__ = "message_hides"
    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_msg_hide"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("messages.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)

    message: Mapped[Message] = relationship(back_populates="hidden_for")


class ChatMedia(Base, TimestampMixin):
    __tablename__ = "chat_media"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    uploader_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(16), nullable=False)
    url: Mapped[str] = mapped_column(String(512), nullable=False)
    meta: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    attached: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class Friendship(Base, TimestampMixin):
    __tablename__ = "friendships"
    __table_args__ = (UniqueConstraint("user_low_id", "user_high_id", name="uq_friendship"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_low_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    user_high_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    requester_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True, nullable=False)
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    decline_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_declined_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class LiveSession(Base, TimestampMixin):
    __tablename__ = "live_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    my_language: Mapped[str] = mapped_column(String(8), nullable=False)
    other_language: Mapped[str] = mapped_column(String(8), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    turns: Mapped[list[LiveTurn]] = relationship(back_populates="session", cascade="all, delete-orphan")


class LiveTurn(Base, TimestampMixin):
    __tablename__ = "live_turns"
    __table_args__ = (UniqueConstraint("session_id", "client_turn_id", name="uq_client_turn"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("live_sessions.id", ondelete="CASCADE"), index=True)
    client_turn_id: Mapped[str] = mapped_column(String(64), nullable=False)
    speaker: Mapped[str] = mapped_column(String(8), nullable=False)  # me | other
    source_language: Mapped[str] = mapped_column(String(8), nullable=False)
    target_language: Mapped[str] = mapped_column(String(8), nullable=False)
    text_original: Mapped[str | None] = mapped_column(Text, nullable=True)
    text_translated: Mapped[str | None] = mapped_column(Text, nullable=True)
    audio_original_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    audio_tts_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    audio_duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tts_duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="done", nullable=False)

    session: Mapped[LiveSession] = relationship(back_populates="turns")
