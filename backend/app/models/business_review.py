from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


class BusinessReview(Base, TimestampMixin):
    """Kompaniya haqida otziv — faqat approved va yashirilmagan bo‘lsa ommaga ko‘rinadi."""

    __tablename__ = "business_reviews"
    __table_args__ = (
        UniqueConstraint("business_user_id", "author_id", name="uq_business_review_author"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    business_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)  # 1..5
    text: Mapped[str] = mapped_column(String(1000), default="", nullable=False)
    # pending | approved | rejected
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True, nullable=False)
    moderation_note: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    moderated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    moderated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)

    client_ip: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    ai_flags: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    fake_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    fake_signals: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)

    hidden_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    hidden_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    hidden_reason: Mapped[str] = mapped_column(String(500), default="", nullable=False)

    company_reply: Mapped[str] = mapped_column(String(1000), default="", nullable=False)
    company_replied_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    business_user = relationship("User", foreign_keys=[business_user_id])
    author = relationship("User", foreign_keys=[author_id])
