from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class MessageResponse(BaseModel):
    message: str


class ResendMessageResponse(MessageResponse):
    resend_after_seconds: int = Field(ge=0)


class PaginationOut(BaseModel, Generic[T]):
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total: int = Field(ge=0)
    items: list[T]
