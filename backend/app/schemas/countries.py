from __future__ import annotations

from pydantic import BaseModel, Field


class CountryOut(BaseModel):
    code: str = Field(min_length=2, max_length=2)
    name_uz: str
    name_ru: str
    name_en: str
    flag_emoji: str = ""


class CountryListOut(BaseModel):
    version: str
    items: list[CountryOut]
