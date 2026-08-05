"""Business document verification — models."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


class BusinessVerificationRequest(Base, TimestampMixin):
    __tablename__ = "business_verification_requests"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    business_id: Mapped[int] = mapped_column(
        ForeignKey("business_profiles.id", ondelete="CASCADE"), nullable=False
    )
    # draft | pending | approved | rejected
    status: Mapped[str] = mapped_column(String(16), default="draft", nullable=False)
    note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    admin_note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    reviewed_by_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
    submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    documents: Mapped[list[BusinessVerificationDocument]] = relationship(
        back_populates="request",
        cascade="all, delete-orphan",
        order_by="BusinessVerificationDocument.id",
    )


class BusinessVerificationDocument(Base, TimestampMixin):
    __tablename__ = "business_verification_documents"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("business_verification_requests.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    doc_type: Mapped[str] = mapped_column(String(40), nullable=False)
    url: Mapped[str] = mapped_column(String(512), nullable=False)
    file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # pending | approved | rejected | resubmit
    review_status: Mapped[str] = mapped_column(String(16), default="pending", nullable=False)
    review_note: Mapped[str | None] = mapped_column(String(500), nullable=True)

    request: Mapped[BusinessVerificationRequest] = relationship(
        back_populates="documents"
    )
