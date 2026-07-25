from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

LiveSpeaker = Literal["me", "other"]
LiveTurnStatus = Literal["done", "failed"]


class LiveLanguageOut(BaseModel):
    code: str
    stt: bool
    tts: bool
    tts_voices: list[str]
    native_name: str | None = None
    flag_emoji: str | None = None
    flag_url: str | None = None
    flag_country: str | None = None


class LiveLanguagesOut(BaseModel):
    languages: list[LiveLanguageOut]


class LiveSessionCreateIn(BaseModel):
    my_language: str = Field(min_length=2, max_length=8)
    other_language: str = Field(min_length=2, max_length=8)


class LiveSessionUpdateIn(BaseModel):
    my_language: str = Field(min_length=2, max_length=8)
    other_language: str = Field(min_length=2, max_length=8)


class LiveSessionOut(BaseModel):
    id: int
    my_language: str
    other_language: str
    started_at: datetime
    ended_at: datetime | None = None
    turn_count: int = 0
    preview: str | None = None


class LiveSessionListOut(BaseModel):
    items: list[LiveSessionOut]
    has_more: bool = False


class LiveTurnOut(BaseModel):
    id: int
    client_turn_id: str
    session_id: int
    speaker: LiveSpeaker
    source_language: str
    target_language: str
    text_original: str | None = None
    text_translated: str | None = None
    audio_original_url: str | None = None
    audio_tts_url: str | None = None
    audio_duration_seconds: int | None = None
    tts_duration_seconds: int | None = None
    status: LiveTurnStatus
    created_at: datetime


class LiveTurnListOut(BaseModel):
    items: list[LiveTurnOut]
    has_more: bool


class LiveOcrTranslateOut(BaseModel):
    text_original: str
    text_translated: str
    source_language: str | None = None
    target_language: str
    audio_tts_url: str | None = None
    session_id: int | None = None
    turn_id: int | None = None
    client_turn_id: str | None = None
    created_at: datetime | None = None
