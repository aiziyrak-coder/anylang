from __future__ import annotations

from pydantic import BaseModel, Field


class DealDocumentOut(BaseModel):
    message_id: int
    title: str = ""
    kind: str = "file"
    url: str | None = None


class DealDocumentCandidateOut(BaseModel):
    message_id: int
    title: str = ""
    kind: str = "file"
    url: str | None = None
    created_at: str | None = None


class DealOut(BaseModel):
    id: int
    chat_id: int
    product: str = ""
    price: str = ""
    currency: str = "USD"
    quantity: str = ""
    unit: str = ""
    delivery: str = ""
    payment: str = ""
    status: str = "open"
    version: int = 1
    documents: list[DealDocumentOut] = Field(default_factory=list)
    accepted_by: list[int] = Field(default_factory=list)
    accepted_count: int = 0
    viewer_accepted: bool = False
    created_by: int
    updated_by: int | None = None
    updated_at: str | None = None


class DealGetOut(BaseModel):
    deal: DealOut | None = None
    candidates: list[DealDocumentCandidateOut] = Field(default_factory=list)


class DealUpdateIn(BaseModel):
    product: str | None = Field(default=None, max_length=240)
    price: str | None = Field(default=None, max_length=64)
    currency: str | None = Field(default=None, max_length=8)
    quantity: str | None = Field(default=None, max_length=64)
    unit: str | None = Field(default=None, max_length=32)
    delivery: str | None = Field(default=None, max_length=240)
    payment: str | None = Field(default=None, max_length=240)


class DealAttachDocumentIn(BaseModel):
    message_id: int
