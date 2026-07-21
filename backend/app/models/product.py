from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


class Product(Base, TimestampMixin):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    seller_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    short_description: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    currency: Mapped[str] = mapped_column(String(8), default="USD", nullable=False)
    category: Mapped[str] = mapped_column(String(64), default="other", nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="draft", index=True, nullable=False)
    views_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_top_pinned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    attributes: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)

    images: Mapped[list[ProductImage]] = relationship(
        back_populates="product", cascade="all, delete-orphan", order_by="ProductImage.position"
    )


class ProductImage(Base, TimestampMixin):
    __tablename__ = "product_images"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    product_id: Mapped[int | None] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=True, index=True
    )
    uploader_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    url: Mapped[str] = mapped_column(String(512), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    attached_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    product: Mapped[Product | None] = relationship(back_populates="images")


class ProductFavorite(Base, TimestampMixin):
    __tablename__ = "product_favorites"
    __table_args__ = (UniqueConstraint("user_id", "product_id", name="uq_favorite"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)


class ProductView(Base):
    """Dedup views: one per user per product per 24h window start."""

    __tablename__ = "product_views"
    __table_args__ = (UniqueConstraint("user_id", "product_id", "day_bucket", name="uq_view_day"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    day_bucket: Mapped[str] = mapped_column(String(10), nullable=False)  # YYYY-MM-DD UTC
