from __future__ import annotations

from pydantic import BaseModel, Field


class MarketInsightOut(BaseModel):
    country: str
    topic: str = ""
    trend: str = "demand_up"  # demand_up | import_up | demand_down
    message: str
    confidence: float = Field(default=0.5, ge=0, le=1)
    signal: str = "rules"


class MarketAnalyticsOut(BaseModel):
    focus_summary: str = ""
    items: list[MarketInsightOut] = Field(default_factory=list)
    generated_by: str = "rules"  # rules | openai | curated
