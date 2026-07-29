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


class ProductVideoUploadOut(BaseModel):
    url: str


class ProductSellerOut(BaseModel):
    id: int
    company_name: str
    logo_url: str | None = None
    verified_badge: bool
    country: str | None = None
    business_role: str | None = None
    rating: float | None = None
    reviews_count: int = 0
    moq: str | None = None
    export_countries: list[str] = Field(default_factory=list)
    lead_time: str | None = None
    incoterms: list[str] = Field(default_factory=list)
    factory_verification: dict | None = None


class ProductTrustBadgesOut(BaseModel):
    factory_verified: bool = False
    iso: bool = False
    trade_assurance: bool = False
    premium: bool = False
    has_any: bool = False


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
    trust_badges: ProductTrustBadgesOut | None = None
    capabilities: list[str] = Field(default_factory=list)

    @field_serializer("price")
    @classmethod
    def serialize_price(cls, value: str) -> str:
        return value


class ProductTopRequestOut(BaseModel):
    id: int
    product_id: int
    seller_id: int
    status: Literal[
        "pending",
        "approved",
        "rejected",
        "cancelled",
        "queued",
        "active",
        "expired",
    ]
    note: str = ""
    admin_note: str = ""
    created_at: datetime
    reviewed_at: datetime | None = None
    paid_at: datetime | None = None
    activated_at: datetime | None = None
    expires_at: datetime | None = None
    seconds_left: int | None = None
    queue_position: int | None = None
    can_extend: bool = False
    product_name: str | None = None
    is_top_pinned: bool | None = None
    price_usd: str | None = None
    period_days: int | None = None
    max_slots: int | None = None


class ProductDetailOut(ProductOut):
    description: str
    category: str
    images: list[ProductImageOut]
    attributes: list[ProductAttributeOut]
    seller: ProductSellerOut
    top_request: ProductTopRequestOut | None = None
    video_url: str | None = None
    factory_video_url: str | None = None
    process_video_url: str | None = None
    moq: str | None = None
    shipping_info: str | None = None
    shipping_countries: list[str] = Field(default_factory=list)
    rating: float | None = None
    reviews_count: int = 0


class ProductListOut(BaseModel):
    items: list[ProductOut]
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    total: int = Field(ge=0)
    has_more: bool


class ManufacturerMapCompanyOut(BaseModel):
    id: int
    company_name: str
    verified: bool = False
    factory_verified: bool = False
    product_count: int = Field(ge=0)


class ManufacturerMapCountryOut(BaseModel):
    country: str = Field(min_length=2, max_length=2)
    manufacturer_count: int = Field(ge=0)
    product_count: int = Field(ge=0)
    companies: list[ManufacturerMapCompanyOut] = Field(default_factory=list)


class ManufacturersMapOut(BaseModel):
    items: list[ManufacturerMapCountryOut] = Field(default_factory=list)
    total_manufacturers: int = Field(ge=0, default=0)
    total_countries: int = Field(ge=0, default=0)


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
    capabilities: list[str] = Field(default_factory=list, max_length=8)
    status: ProductStatus = "draft"
    video_url: str | None = Field(default=None, max_length=512)
    factory_video_url: str | None = Field(default=None, max_length=512)
    process_video_url: str | None = Field(default=None, max_length=512)
    moq: str | None = Field(default=None, max_length=120)
    shipping_info: str | None = Field(default=None, max_length=255)
    shipping_countries: list[str] = Field(default_factory=list, max_length=50)


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
    capabilities: list[str] | None = Field(default=None, max_length=8)
    status: ProductStatus | None = None
    video_url: str | None = Field(default=None, max_length=512)
    factory_video_url: str | None = Field(default=None, max_length=512)
    process_video_url: str | None = Field(default=None, max_length=512)
    moq: str | None = Field(default=None, max_length=120)
    shipping_info: str | None = Field(default=None, max_length=255)
    shipping_countries: list[str] | None = Field(default=None, max_length=50)
