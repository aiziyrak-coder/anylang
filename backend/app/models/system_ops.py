from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class SystemFeatureFlag(Base, TimestampMixin):
    __tablename__ = "system_feature_flags"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class SystemErrorEvent(Base):
    __tablename__ = "system_error_events"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    fingerprint: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    level: Mapped[str] = mapped_column(String(16), default="error", nullable=False)
    error_code: Mapped[str] = mapped_column(String(64), default="", nullable=False, index=True)
    message: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    path: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    method: Mapped[str] = mapped_column(String(16), default="", nullable=False)
    status_code: Mapped[int | None] = mapped_column(Integer, nullable=True)
    meta: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
