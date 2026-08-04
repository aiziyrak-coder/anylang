from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PushTokenRegisterIn(BaseModel):
    token: str = Field(min_length=8, max_length=512)
    device_id: str | None = Field(default=None, max_length=64)
    platform: Literal["android", "ios", "web"]
    app_version: str | None = Field(default=None, max_length=32)


class PushTokenUnregisterIn(BaseModel):
    token: str | None = Field(default=None, min_length=8, max_length=512)
    device_id: str | None = Field(default=None, max_length=64)


class PushTokenOut(BaseModel):
    id: int
    platform: str
    device_id: str | None = None
    app_version: str | None = None
    last_seen_at: datetime
    message: str = "OK"
