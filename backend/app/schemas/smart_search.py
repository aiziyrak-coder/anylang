from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.product import ProductOut


class SmartSearchParsedOut(BaseModel):
    country: str | None = None
    category: str | None = None
    business_role: str | None = None
    verified_only: bool = False
    search: str | None = None
    sort: str | None = None
    min_price: float | None = None
    max_price: float | None = None


class SmartSearchOut(BaseModel):
    items: list[ProductOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool
    raw_query: str = ""
    interpretation: str = ""
    parsed: SmartSearchParsedOut = Field(default_factory=SmartSearchParsedOut)
    generated_by: str = "rules"
