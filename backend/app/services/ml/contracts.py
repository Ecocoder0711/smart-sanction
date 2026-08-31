"""Typed contract implemented by a future ML matching engine."""

from collections.abc import Sequence
from decimal import Decimal
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field


class MLApplicantInput(BaseModel):
    """Minimal persisted applicant features exposed to the model."""

    model_config = ConfigDict(frozen=True)

    user_id: int = Field(gt=0)
    annual_income: Decimal = Field(ge=0)
    category: str = Field(min_length=1)


class MLCandidateInput(BaseModel):
    """Minimal scheme and request features exposed to the model."""

    model_config = ConfigDict(frozen=True)

    scheme_id: int = Field(gt=0)
    category: str = Field(min_length=1)
    requested_amount: Decimal = Field(gt=0)
    max_loan_limit: Decimal = Field(ge=0)
    max_income_limit: Decimal = Field(ge=0)
    annual_interest_rate: Decimal = Field(ge=0)
    tenure_months: int = Field(gt=0)


class MLMatchingInput(BaseModel):
    """Batch input passed to one future prediction call."""

    model_config = ConfigDict(frozen=True)

    applicant: MLApplicantInput
    candidates: tuple[MLCandidateInput, ...]


class MLCandidatePrediction(BaseModel):
    """Prediction values keyed to a candidate scheme."""

    model_config = ConfigDict(frozen=True)

    scheme_id: int = Field(gt=0)
    match_score: Decimal | None = Field(default=None, ge=0, le=1)
    approval_probability: Decimal | None = Field(default=None, ge=0, le=1)
    rank: int | None = Field(default=None, gt=0)


class MLUnavailableError(RuntimeError):
    """Raised by an installed engine when it cannot currently predict."""


class MatchingEngine(Protocol):
    """Interface a future local or remote model adapter must implement."""

    @property
    def available(self) -> bool:
        """Return whether the engine is ready for prediction."""
        ...

    def predict(self, payload: MLMatchingInput) -> Sequence[MLCandidatePrediction]:
        """Return zero or one validated prediction per candidate scheme."""
        ...
