"""Chat review cases — complaint → chat → decision (superadmin)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class ChatReviewCase(Base, TimestampMixin):
    __tablename__ = "chat_review_cases"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    chat_id: Mapped[int] = mapped_column(
        ForeignKey("chats.id", ondelete="CASCADE"), index=True, nullable=False
    )
    reporter_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    reported_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # spam | harassment | scam | pii | keyword | other
    reason: Mapped[str] = mapped_column(String(64), nullable=False, default="other")
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    # open | reviewing | decided
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="open", index=True)
    # warn | ban | dismiss | none
    decision: Mapped[str | None] = mapped_column(String(32), nullable=True)
    decision_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    decided_by_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # report | search
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="report")
    search_query: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_by_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
