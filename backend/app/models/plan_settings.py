"""Admin-editable plan catalog + subscription policy models."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, Integer, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class PlanCatalogOverride(Base):
    __tablename__ = "plan_catalog_overrides"

    plan_code: Mapped[str] = mapped_column(String(32), primary_key=True)
    monthly_usd: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    trial_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    limits: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    region_currency: Mapped[dict] = mapped_column(
        JSONB, default=lambda: {"default": "USD"}, nullable=False
    )
    features_override: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class SubscriptionPolicy(Base):
    __tablename__ = "subscription_policies"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    grace_days: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
    soft_lock_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    reminder_days: Mapped[list] = mapped_column(JSONB, default=lambda: [7, 3, 1], nullable=False)
    churn_reasons: Mapped[list] = mapped_column(
        JSONB,
        default=lambda: [
            "too_expensive",
            "not_using",
            "switched_plan",
            "missing_features",
            "other",
        ],
        nullable=False,
    )
    soft_lock_message: Mapped[dict] = mapped_column(
        JSONB,
        default=lambda: {
            "uz": "Obuna muddati tugadi — grace davri",
            "ru": "Подписка истекла — льготный период",
            "en": "Subscription expired — grace period",
        },
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
