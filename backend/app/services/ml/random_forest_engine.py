"""RandomForest MatchingEngine adapter that serves the trained artifact.

Loads the pipeline exported by data/ml/train_random_forest.py and predicts
an approval probability per candidate scheme. If the artifact is missing or
unreadable, the adapter reports itself unavailable instead of raising, so a
fresh checkout or container without the artifact still starts and serves
deterministic matching normally (see docs/ml-integration.md).
"""

from __future__ import annotations

from collections.abc import Sequence
from decimal import Decimal
from functools import lru_cache
from pathlib import Path

import joblib
import pandas as pd

from app.services.ml.contracts import (
    MLCandidatePrediction,
    MLMatchingInput,
    MLUnavailableError,
)
from app.services.ml.similarity import compute_similarity_scores

ARTIFACT_PATH = Path(__file__).resolve().parent / "artifacts" / "random_forest_v1.joblib"

# Column name and order must match FEATURE_COLUMNS in
# data/ml/train_random_forest.py, since the fitted ColumnTransformer expects
# this shape.
FEATURE_COLUMNS = ["annual_income", "desired_loan_amount", "previous_default", "category"]


def _load_pipeline(artifact_path: Path) -> object | None:
    """Return a usable trained pipeline, or None if the artifact is unusable.

    Reading a possibly-corrupt artifact is not a narrow failure mode. Feeding
    damaged bytes to pickle was measured to raise EOFError, IndexError,
    KeyError, ValueError, TypeError, AttributeError, MemoryError, zlib.error
    or UnpicklingError depending purely on where the damage lands, and an
    incompatible scikit-learn version adds more (private internals such as
    ColumnTransformer's remainder handling change with no deprecation cycle).
    Enumerating that open-ended set would leave the API returning 500 on
    whichever type was missed, so the load is guarded broadly.

    That breadth is safe here because the guarded block is exactly one
    third-party call with no logic of ours inside it, so it cannot swallow a
    bug in this codebase; BaseException (KeyboardInterrupt, SystemExit) still
    propagates untouched.
    """
    try:
        pipeline = joblib.load(artifact_path)
    except Exception:  # noqa: BLE001 - see docstring; scope is one library call
        return None

    # A file can unpickle cleanly and still not be the trained pipeline -- a
    # stale export, or the wrong file copied into place. Reject it now, while
    # the caller can still degrade to ml_status "unavailable", rather than at
    # request time where a missing predict_proba surfaces as a 500.
    if not callable(getattr(pipeline, "predict_proba", None)):
        return None
    return pipeline


class RandomForestAdapter:
    """Loads a trained pipeline and predicts approval probability per candidate."""

    def __init__(self, artifact_path: Path = ARTIFACT_PATH) -> None:
        self._pipeline = _load_pipeline(artifact_path)

    @property
    def available(self) -> bool:
        """Return whether a usable trained pipeline was loaded."""
        return self._pipeline is not None

    def predict(self, payload: MLMatchingInput) -> Sequence[MLCandidatePrediction]:
        """Return one approval-probability prediction per candidate."""
        if not self.available:
            raise MLUnavailableError("RandomForest model artifact is not loaded")

        if not payload.candidates:
            # Deterministic eligibility matched no scheme. That is a valid
            # empty business result, but predict_proba rejects a zero-row
            # frame ("Found array with 0 sample(s)"), so return before one is
            # built. compute_similarity_scores short-circuits identically.
            return []

        # TODO: add previous_default to User schema so real applicant history
        # can replace this hardcoded default once it's persisted.
        previous_default = False

        features = pd.DataFrame(
            [
                {
                    "annual_income": float(payload.applicant.annual_income),
                    "desired_loan_amount": float(candidate.requested_amount),
                    "previous_default": previous_default,
                    "category": payload.applicant.category,
                }
                for candidate in payload.candidates
            ],
            columns=FEATURE_COLUMNS,
        )
        approval_probabilities = self._pipeline.predict_proba(features)[:, 1]
        similarity_scores = compute_similarity_scores(payload.applicant, payload.candidates)

        # Rank reflects match_score (the applicant-to-scheme financial fit),
        # since that is what the final API response is ordered by -- see
        # matching_service.py. sorted() is stable, and payload.candidates
        # already arrives in scheme.id order, so equal scores tie-break by
        # scheme.id deterministically.
        ranked_order = sorted(
            range(len(similarity_scores)),
            key=lambda i: similarity_scores[i],
            reverse=True,
        )
        ranks = {index: rank for rank, index in enumerate(ranked_order, start=1)}

        return [
            MLCandidatePrediction(
                scheme_id=candidate.scheme_id,
                # Clamped defensively: both vectors are non-negative, so
                # cosine similarity is mathematically within [0, 1] already,
                # but this guards against a float epsilon overshoot tripping
                # the contract's ge=0/le=1 validation.
                match_score=Decimal(str(round(max(0.0, min(1.0, similarity)), 5))),
                approval_probability=Decimal(str(round(float(approval), 5))),
                rank=ranks[i],
            )
            for i, (candidate, similarity, approval) in enumerate(
                zip(payload.candidates, similarity_scores, approval_probabilities)
            )
        ]


@lru_cache
def get_ml_engine() -> RandomForestAdapter:
    """Return one process-wide adapter, loaded lazily on first use."""
    return RandomForestAdapter()
