from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


class SupportSession(Base, TimestampMixin):
    __tablename__ = "support_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(16), default="active", index=True, nullable=False
    )  # active | completed
    locale: Mapped[str] = mapped_column(String(16), default="uz", nullable=False)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    preview: Mapped[str | None] = mapped_column(String(240), nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    messages: Mapped[list[SupportMessage]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SupportMessage.id",
    )


class SupportMessage(Base, TimestampMixin):
    __tablename__ = "support_messages"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("support_sessions.id", ondelete="CASCADE"), index=True, nullable=False
    )
    role: Mapped[str] = mapped_column(String(16), nullable=False)  # user | assistant
    content: Mapped[str] = mapped_column(Text, nullable=False)

    session: Mapped[SupportSession] = relationship(back_populates="messages")
