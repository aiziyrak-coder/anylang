"""Partner business application (outreach anketa) models."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
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


class PartnerApplication(Base, TimestampMixin):
    __tablename__ = "partner_applications"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    status: Mapped[str] = mapped_column(
        String(16), default="pending", index=True, nullable=False
    )  # pending(new) | review | approved | rejected

    # Credentials chosen by applicant (account created only on approve)
    email: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    # Contact
    contact_name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    source_lang: Mapped[str | None] = mapped_column(String(8), nullable=True)

    # Business profile
    company_name: Mapped[str] = mapped_column(String(200), nullable=False)
    country: Mapped[str | None] = mapped_column(String(2), nullable=True)
    business_role: Mapped[str | None] = mapped_column(String(32), nullable=True)
    website: Mapped[str | None] = mapped_column(String(255), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(300), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    founded_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    moq: Mapped[str | None] = mapped_column(String(120), nullable=True)
    production_capacity: Mapped[str | None] = mapped_column(String(160), nullable=True)
    lead_time: Mapped[str | None] = mapped_column(String(120), nullable=True)
    certificates: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    export_countries: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    payment_methods: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    incoterms: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)

    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    factory_image_urls: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    factory_video_url: Mapped[str | None] = mapped_column(String(512), nullable=True)

    admin_note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_user_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True, index=True)
    submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    products: Mapped[list[PartnerApplicationProduct]] = relationship(
        back_populates="application",
        cascade="all, delete-orphan",
        order_by="PartnerApplicationProduct.position",
    )


class PartnerApplicationProduct(Base, TimestampMixin):
    __tablename__ = "partner_application_products"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    application_id: Mapped[int] = mapped_column(
        ForeignKey("partner_applications.id", ondelete="CASCADE"), index=True, nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    short_description: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    currency: Mapped[str] = mapped_column(String(8), default="USD", nullable=False)
    category: Mapped[str] = mapped_column(String(64), default="other", nullable=False)
    moq: Mapped[str | None] = mapped_column(String(120), nullable=True)
    shipping_info: Mapped[str | None] = mapped_column(String(255), nullable=True)
    image_urls: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    video_url: Mapped[str | None] = mapped_column(String(512), nullable=True)

    application: Mapped[PartnerApplication] = relationship(back_populates="products")
