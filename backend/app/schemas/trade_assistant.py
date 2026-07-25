from __future__ import annotations

from pydantic import BaseModel, Field


class TradeHistoryItem(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class TradeAssistantIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    history: list[TradeHistoryItem] = Field(default_factory=list, max_length=40)
    locale: str = Field(default="uz", max_length=16)
    """Agar berilsa — faqat shu kompaniya katalogi bo‘yicha ishlaydi."""
    seller_id: int | None = None


class TradeProductMatchOut(BaseModel):
    id: int
    name: str
    price: str | None = None
    currency: str | None = None
    image_url: str | None = None
    seller_id: int | None = None
    seller_name: str | None = None


class TradeSellerMatchOut(BaseModel):
    id: int
    company_name: str
    country: str | None = None
    business_role: str | None = None
    verified_badge: bool = False
    logo_url: str | None = None
    products_count: int = 0


class TradeAssistantOut(BaseModel):
    reply: str
    agent_name: str = "AnyTrade"
    products: list[TradeProductMatchOut] = Field(default_factory=list)
    sellers: list[TradeSellerMatchOut] = Field(default_factory=list)
    next_questions: list[str] = Field(default_factory=list)
