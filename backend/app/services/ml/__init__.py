"""Extension point for a future SMART-SANCTION matching model."""

from app.services.ml.contracts import (
    MLApplicantInput,
    MLCandidateInput,
    MLCandidatePrediction,
    MLMatchingInput,
    MLUnavailableError,
    MatchingEngine,
)

__all__ = [
    "MLApplicantInput",
    "MLCandidateInput",
    "MLCandidatePrediction",
    "MLMatchingInput",
    "MLUnavailableError",
    "MatchingEngine",
]
