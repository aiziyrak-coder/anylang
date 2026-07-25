from __future__ import annotations

from pydantic import BaseModel, Field


class GroupStatCountryOut(BaseModel):
    code: str
    message_count: int = 0
    member_count: int = 0


class GroupStatCompanyOut(BaseModel):
    user_id: int
    company_name: str
    logo_url: str | None = None
    country: str | None = None
    message_count: int = 0
    verified_badge: bool = False


class GroupStatProductsOut(BaseModel):
    user_id: int
    company_name: str
    logo_url: str | None = None
    product_count: int = 0
    shared_in_chat: int = 0


class GroupStatDealsOut(BaseModel):
    user_id: int
    company_name: str
    logo_url: str | None = None
    deal_count: int = 0
    invoice_count: int = 0
    offer_count: int = 0


class GroupStatsOut(BaseModel):
    chat_id: int
    member_count: int = 0
    message_count: int = 0
    top_country: GroupStatCountryOut | None = None
    top_company: GroupStatCompanyOut | None = None
    top_products: GroupStatProductsOut | None = None
    top_deals: GroupStatDealsOut | None = None
    countries: list[GroupStatCountryOut] = Field(default_factory=list)
    companies: list[GroupStatCompanyOut] = Field(default_factory=list)
    products_leaders: list[GroupStatProductsOut] = Field(default_factory=list)
    deals_leaders: list[GroupStatDealsOut] = Field(default_factory=list)
