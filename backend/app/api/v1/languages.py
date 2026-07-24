from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services import languages as languages_service

router = APIRouter()


class LanguageOut(BaseModel):
    code: str
    native_name: str
    flag_country: str
    flag_emoji: str = ""
    flag_url: str
    stt: bool = True
    tts: bool = False
    tts_voices: list[str] = []


class LanguageListOut(BaseModel):
    version: str
    items: list[LanguageOut]


@router.get("", response_model=LanguageListOut)
async def list_languages(db: AsyncSession = Depends(get_db)) -> LanguageListOut:
    return LanguageListOut.model_validate(await languages_service.list_languages(db))
