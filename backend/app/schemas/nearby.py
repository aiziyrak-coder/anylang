from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class LocationUpdateIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    sharing_enabled: bool | None = None


class LocationSharingIn(BaseModel):
    enabled: bool


class LocationOut(BaseModel):
    location_lat: float | None = None
    location_lng: float | None = None
    location_updated_at: datetime | None = None
    location_sharing_enabled: bool = False


class NearbyUserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    avatar_url: str | None = None
    number: str | None = None
    native_language: str
    country: str | None = None
    verified_badge: bool = False
    is_business: bool = False
    distance_m: int = Field(ge=0)
    location_updated_at: datetime | None = None


class NearbyOut(BaseModel):
    locked: bool = False
    radius_m: int = 2000
    total_count: int = 0
    items: list[NearbyUserOut] = Field(default_factory=list)
