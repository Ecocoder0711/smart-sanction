"""Channel partner response schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class PartnerResponse(BaseModel):
    """Channel partner representation without any ML score."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    bank_name: str
    branch_code: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    npa_percentage: Decimal = Field(ge=0, le=100, max_digits=7, decimal_places=4)
    quota_remaining: Decimal = Field(ge=0, max_digits=14, decimal_places=2)
    is_active: bool
    created_at: datetime
    updated_at: datetime


class NearbyPartnerResponse(PartnerResponse):
    """Future deterministic nearby-partner result."""

    distance_km: float = Field(ge=0)


class RecommendedPartnerResponse(NearbyPartnerResponse):
    """Partner recommended only by deterministic availability and distance rules."""
