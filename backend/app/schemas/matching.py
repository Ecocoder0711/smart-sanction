"""Deterministic matching response and future ML result contracts."""

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.calculator import CalculatorResponse
from app.schemas.partner import RecommendedPartnerResponse
from app.schemas.scheme import SchemeResponse


class MatchRequest(BaseModel):
    """Loan preferences supplied by the authenticated applicant."""

    model_config = ConfigDict(extra="forbid")

    requested_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    tenure_months: int = Field(default=60, gt=0, le=1200)


class CandidateEligibility(BaseModel):
    """Explainable deterministic eligibility outcome for one candidate."""

    eligible: bool
    reasons: list[str]


class MLResult(BaseModel):
    """Optional values supplied only by a configured future ML engine."""

    match_score: Decimal | None = Field(default=None, ge=0, le=1)
    approval_probability: Decimal | None = Field(default=None, ge=0, le=1)
    rank: int | None = Field(default=None, gt=0)


class MatchCandidate(BaseModel):
    """One eligible scheme with finance and partner-proximity results."""

    scheme: SchemeResponse
    eligibility: CandidateEligibility
    requested_amount: Decimal
    financial: CalculatorResponse
    partners: list[RecommendedPartnerResponse] = Field(default_factory=list)
    partner_message: str
    ml: MLResult | None = None


class MatchResponse(BaseModel):
    """Frontend-friendly deterministic matching result."""

    requested_amount: Decimal
    tenure_months: int
    candidate_count: int = Field(ge=0)
    message: str
    candidates: list[MatchCandidate]
    ml_status: Literal["available", "unavailable"] = "unavailable"


# Compatibility aliases for code importing the Phase 6 placeholder names.
MatchingRequest = MatchRequest
MatchingResponse = MatchResponse
