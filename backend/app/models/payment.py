from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, DateTime, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class Payment(Base, TimestampMixin):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(32), nullable=False)  # subscription | number
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    provider: Mapped[str] = mapped_column(String(32), nullable=False, default="mock")
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="USD")
    plan: Mapped[str | None] = mapped_column(String(32), nullable=True)
    billing_cycle: Mapped[str | None] = mapped_column(String(32), nullable=True)
    number: Mapped[str | None] = mapped_column(String(7), nullable=True)
    stripe_session_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    stripe_payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    meta: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, nullable=False)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
