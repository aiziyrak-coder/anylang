from __future__ import annotations

from sqlalchemy import BigInteger, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import TimestampMixin


FEED_POST_TYPES = (
    "new_product",
    "new_factory",
    "new_certificate",
    "exhibition",
    "discount",
)


class BusinessFeedPost(Base, TimestampMixin):
    """Biznes yangiliklari — Instagram emas, faqat savdo yangiliklari."""

    __tablename__ = "business_feed_posts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    author_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    post_type: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str] = mapped_column(String(800), default="", nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    meta: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)

    author = relationship("User", foreign_keys=[author_id])
