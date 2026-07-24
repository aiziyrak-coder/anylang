from __future__ import annotations

from sqlalchemy import Boolean, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class Language(Base, TimestampMixin):
    __tablename__ = "languages"

    code: Mapped[str] = mapped_column(String(8), primary_key=True)
    native_name: Mapped[str] = mapped_column(String(64), nullable=False)
    flag_country: Mapped[str] = mapped_column(String(2), nullable=False)
    flag_emoji: Mapped[str] = mapped_column(String(16), nullable=False, default="")
    flag_url: Mapped[str] = mapped_column(Text, nullable=False)
    stt: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    tts: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    tts_voices: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
