from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer

ProductStatus = Literal["draft", "published", "archived"]
ProductSort = Literal["newest", "price_asc", "price_desc", "most_viewed"]
ProductCurrency = Literal["USD", "EUR", "RUB", "UZS"]
ProductCategory = Literal[
    "clothing_accessories",
    "pottery",
    "woodwork",
    "jewelry",
    "other",
]


class ProductAttributeIn(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    value: str = Field(min_length=1, max_length=40)


class ProductAttributeOut(BaseModel):
    name: str
    value: str


class ProductImageOut(BaseModel):
    id: int
    url: str
    is_primary: bool
    position: int


class ProductImageUploadOut(BaseModel):
    id: int
    url: str


class ProductSellerOut(BaseModel):
    id: int
    company_name: str
    logo_url: str | None = None
    verified_badge: bool
    country: str | None = None
    business_role: str | None = None


class ProductOut(BaseModel):
    id: int
    name: str
    short_description: str
    price: str
    currency: str
    primary_image_url: str | None = None
    views_count: int
    is_top: bool
    is_favorited: bool
    status: ProductStatus
    seller_id: int
    created_at: datetime

    @field_serializer("price")
    @classmethod
    def serialize_price(cls, value: str) -> str:
        return value


class ProductTopRequestOut(BaseModel):
    id: int
    product_id: int
    seller_id: int
    status: Literal["pending", "approved", "rejected", "cancelled"]
    note: str = ""
    admin_note: str = ""
    created_at: datetime
    reviewed_at: datetime | None = None
    product_name: str | None = None
    is_top_pinned: bool | None = None


class ProductDetailOut(ProductOut):
    description: str
    category: str
    images: list[ProductImageOut]
    attributes: list[ProductAttributeOut]
    seller: ProductSellerOut
    top_request: ProductTopRequestOut | None = None


class ProductListOut(BaseModel):
    items: list[ProductOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool


class ProductTopOut(BaseModel):
    items: list[ProductOut]


class CategoryOut(BaseModel):
    code: str
    title: str


class FavoriteStatusOut(BaseModel):
    is_favorited: bool


class ProductTopRequestIn(BaseModel):
    note: str = Field(default="", max_length=300)


class ProductTopRequestListOut(BaseModel):
    items: list[ProductTopRequestOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool


class AdminTopRequestReviewIn(BaseModel):
    admin_note: str = Field(default="", max_length=300)


class ProductCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    short_description: str = Field(default="", max_length=120)
    description: str = Field(default="", max_length=500)
    price: Decimal = Field(default=Decimal("0"))
    currency: ProductCurrency = "USD"
    category: ProductCategory = "other"
    image_ids: list[int] = Field(default_factory=list)
    primary_image_id: int | None = None
    attributes: list[ProductAttributeIn] = Field(default_factory=list, max_length=10)
    status: ProductStatus = "draft"


class ProductUpdateIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=100)
    short_description: str | None = Field(default=None, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    price: Decimal | None = None
    currency: ProductCurrency | None = None
    category: ProductCategory | None = None
    image_ids: list[int] | None = None
    primary_image_id: int | None = None
    attributes: list[ProductAttributeIn] | None = Field(default=None, max_length=10)
    status: ProductStatus | None = None
