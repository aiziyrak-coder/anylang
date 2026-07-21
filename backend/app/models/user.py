from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin

if TYPE_CHECKING:
    from app.models.user import FactoryImage


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    full_name: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    number: Mapped[str] = mapped_column(String(7), unique=True, index=True, nullable=False)
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(16), nullable=True)
    country: Mapped[str | None] = mapped_column(String(2), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    app_language: Mapped[str] = mapped_column(String(10), nullable=False, default="uz_UZ")
    native_language: Mapped[str] = mapped_column(String(8), nullable=False, default="uz")
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    verified_badge: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    google_sub: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    last_number_change_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    deletion_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    scheduled_purge_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

    subscription: Mapped[Subscription | None] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    business: Mapped[BusinessProfile | None] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    refresh_tokens: Mapped[list[RefreshToken]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )

    @property
    def is_business(self) -> bool:
        return bool(self.subscription and self.subscription.plan == "business" and self.subscription.is_active)

    @property
    def profile_completed(self) -> bool:
        return bool(self.full_name and self.birth_date and self.gender and self.country)


class RefreshToken(Base, TimestampMixin):
    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    jti: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    family: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    token_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class OtpCode(Base, TimestampMixin):
    __tablename__ = "otp_codes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    purpose: Mapped[str] = mapped_column(String(32), nullable=False)  # verify_email | reset_password
    code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Subscription(Base, TimestampMixin):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    plan: Mapped[str] = mapped_column(String(32), nullable=False, default="basic")
    billing_cycle: Mapped[str | None] = mapped_column(String(16), nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    auto_renew: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    source: Mapped[str] = mapped_column(String(32), default="purchase", nullable=False)

    user: Mapped[User] = relationship(back_populates="subscription")


class BusinessProfile(Base, TimestampMixin):
    __tablename__ = "business_profiles"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    company_name: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    country: Mapped[str | None] = mapped_column(String(2), nullable=True)
    business_role: Mapped[str | None] = mapped_column(String(32), nullable=True)
    website: Mapped[str | None] = mapped_column(String(255), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    founded_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    certificates: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)

    user: Mapped[User] = relationship(back_populates="business")
    factory_images: Mapped[list[FactoryImage]] = relationship(
        back_populates="business", cascade="all, delete-orphan"
    )


class FactoryImage(Base, TimestampMixin):
    __tablename__ = "factory_images"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    business_id: Mapped[int] = mapped_column(ForeignKey("business_profiles.id", ondelete="CASCADE"), index=True)
    url: Mapped[str] = mapped_column(String(512), nullable=False)

    business: Mapped[BusinessProfile] = relationship(back_populates="factory_images")


class NumberGroup(Base, TimestampMixin):
    __tablename__ = "number_groups"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    patterns: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="USD", nullable=False)
    bonus_plan: Mapped[str | None] = mapped_column(String(32), nullable=True)
    bonus_duration_months: Mapped[int | None] = mapped_column(Integer, nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class NumberAssignment(Base, TimestampMixin):
    """Assigned / reserved AnyLang numbers (only occupied rows — not full 10M catalog)."""

    __tablename__ = "number_assignments"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    number: Mapped[str] = mapped_column(String(7), unique=True, index=True, nullable=False)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    group_id: Mapped[int | None] = mapped_column(ForeignKey("number_groups.id"), nullable=True)
    reserved_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reserved_by_user_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    purchased_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class AdminUser(Base, TimestampMixin):
    __tablename__ = "admin_users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(32), default="moderator", nullable=False)  # superadmin|moderator|support
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class AdminAuditLog(Base, TimestampMixin):
    __tablename__ = "admin_audit_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    actor_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    target_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    target_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    meta: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    ip: Mapped[str | None] = mapped_column(String(64), nullable=True)


class AccountRestoreRequest(Base, TimestampMixin):
    __tablename__ = "account_restore_requests"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    number: Mapped[str | None] = mapped_column(String(7), nullable=True)
    reason: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default="pending", index=True
    )  # pending|approved|rejected
    decided_by_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
    decision_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
