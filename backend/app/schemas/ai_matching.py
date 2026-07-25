from __future__ import annotations

from pydantic import BaseModel, Field


class AiMatchCompanyOut(BaseModel):
    id: int
    name: str
    country: str | None = None
    business_role: str | None = None
    logo_url: str | None = None


class AiMatchInsightOut(BaseModel):
    country: str
    count: int = Field(ge=0)
    message: str
    match_type: str = "buyers_looking"
    sample_companies: list[AiMatchCompanyOut] = Field(default_factory=list)


class AiMatchingOut(BaseModel):
    product_summary: str = ""
    items: list[AiMatchInsightOut] = Field(default_factory=list)
    generated_by: str = "rules"  # rules | openai


class AiRecommendationOut(BaseModel):
    user_id: int
    company_name: str
    country: str | None = None
    business_role: str | None = None
    logo_url: str | None = None
    match_percent: int = Field(ge=0, le=100)
    reason: str = ""
    verified: bool = False
    headline: str = ""


class AiRecommendationsOut(BaseModel):
    items: list[AiRecommendationOut] = Field(default_factory=list)
    based_on: str = ""
    total_count: int = Field(default=0, ge=0)
