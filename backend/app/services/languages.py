from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.language import Language
from app.services.language_catalog import LANGUAGES_VERSION, catalog_dicts, live_language_dicts


async def list_languages(db: AsyncSession | None = None) -> dict:
    """Return languages from DB when available; fallback to catalog."""
    if db is not None:
        try:
            rows = (
                await db.execute(
                    select(Language)
                    .where(Language.is_active.is_(True))
                    .order_by(Language.code)
                )
            ).scalars().all()
            if rows:
                items = [
                    {
                        "code": r.code,
                        "native_name": r.native_name,
                        "flag_country": r.flag_country,
                        "flag_emoji": r.flag_emoji,
                        "flag_url": r.flag_url,
                        "stt": r.stt,
                        "tts": r.tts,
                        "tts_voices": list(r.tts_voices or []),
                    }
                    for r in rows
                ]
                return {"version": LANGUAGES_VERSION, "items": items}
        except Exception:
            pass
    return {"version": LANGUAGES_VERSION, "items": catalog_dicts()}


def list_live_languages_sync() -> dict:
    return {"languages": live_language_dicts()}
