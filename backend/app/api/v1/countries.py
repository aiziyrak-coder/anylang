from __future__ import annotations

from fastapi import APIRouter

from app.schemas.countries import CountryListOut
from app.services import countries as countries_service

router = APIRouter()


@router.get("", response_model=CountryListOut)
async def list_countries() -> CountryListOut:
    """Davlatlar katalogi — auth talab qilinmaydi (register uchun)."""
    return CountryListOut.model_validate(countries_service.list_countries())
