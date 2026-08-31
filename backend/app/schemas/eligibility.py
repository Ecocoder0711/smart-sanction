"""Deterministic scheme eligibility contracts."""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.scheme import SchemeResponse


class EligibilityRequest(BaseModel):
    """Authenticated applicant's scheme eligibility input."""

    model_config = ConfigDict(extra="forbid")

    scheme_id: int = Field(gt=0)
    requested_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)


class EligibilityResponse(BaseModel):
    """Explainable deterministic eligibility result."""

    scheme: SchemeResponse
    requested_amount: Decimal
    eligible: bool
    reasons: list[str]

