from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


GroupCatalogSection = Literal["products", "documents", "companies", "all"]


class GroupCatalogProductOut(BaseModel):
    message_id: int | None = None
    product_id: int | None = None
    title: str
    price: str | None = None
    image_url: str | None = None
    subtitle: str | None = None
    source: str = "product"  # product | catalog
    sender_id: int | None = None
    sender_name: str | None = None
    created_at: datetime | None = None


class GroupCatalogDocumentOut(BaseModel):
    message_id: int
    filename: str
    url: str | None = None
    size: int | None = None
    ext: str | None = None
    sender_id: int | None = None
    sender_name: str | None = None
    created_at: datetime | None = None


class GroupCatalogCompanyOut(BaseModel):
    user_id: int
    company_name: str
    logo_url: str | None = None
    country: str | None = None
    business_role: str | None = None
    verified_badge: bool = False
    website: str | None = None
    description: str | None = None
    source: str = "member"  # member | business_card
    message_id: int | None = None


class GroupCatalogOut(BaseModel):
    chat_id: int
    products: list[GroupCatalogProductOut] = Field(default_factory=list)
    documents: list[GroupCatalogDocumentOut] = Field(default_factory=list)
    companies: list[GroupCatalogCompanyOut] = Field(default_factory=list)
    counts: dict[str, int] = Field(default_factory=dict)
