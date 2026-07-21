from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

CatalogSort = Literal["price_asc", "price_desc", "number_asc"]


class NumberGroupBriefOut(BaseModel):
    id: int
    name: str
    price: str
    currency: str
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None


class CatalogItemOut(BaseModel):
    number: str
    group: NumberGroupBriefOut
    is_available: bool = True


class CatalogOut(BaseModel):
    items: list[CatalogItemOut]
    page: int
    limit: int
    total: int
    has_more: bool


class NumberGroupOut(BaseModel):
    id: int
    name: str
    price: str
    currency: str
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    available_count: int = 0


class RandomNumberOut(BaseModel):
    number: str
    group: dict


class ReserveIn(BaseModel):
    number: str = Field(min_length=7, max_length=7)


class ReserveOut(BaseModel):
    number: str
    reserved_until: datetime


class PurchaseIn(BaseModel):
    number: str = Field(min_length=7, max_length=7)
