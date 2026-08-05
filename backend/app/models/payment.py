from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class Payment(Base, TimestampMixin):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(32), nullable=False)  # subscription | number
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending", index=True)
    # mock | stripe | click | paddle
    provider: Mapped[str] = mapped_column(String(32), nullable=False, default="mock", index=True)
    provider_transaction_id: Mapped[str | None] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="USD")
    plan: Mapped[str | None] = mapped_column(String(32), nullable=True)
    billing_cycle: Mapped[str | None] = mapped_column(String(32), nullable=True)
    number: Mapped[str | None] = mapped_column(String(7), nullable=True)
    stripe_session_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    stripe_payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    meta: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, nullable=False)
    # Webhook audit trail (Click prepare/complete, Paddle events, …).
    raw_payload: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Admin ops: refund / chargeback / failed triage
    refund_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    refunded_by_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
    chargeback_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    chargeback_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    triage_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    failed_notified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
