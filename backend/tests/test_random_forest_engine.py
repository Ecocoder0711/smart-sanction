"""Unit tests for RandomForestAdapter's orchestration of the two ML scores.

These tests stub out the trained pipeline (predict_proba) so they exercise
match_score/approval_probability/rank wiring deterministically, without
depending on the gitignored random_forest_v1.joblib artifact being present.
"""

from decimal import Decimal
from pathlib import Path

import numpy as np
import pytest

from app.services.ml.contracts import (
    MLApplicantInput,
    MLCandidateInput,
    MLMatchingInput,
    MLUnavailableError,
)
from app.services.ml.random_forest_engine import RandomForestAdapter

MISSING_ARTIFACT = Path("/nonexistent/random_forest_v1.joblib")


class _FakePipeline:
    """Stand-in for the trained sklearn Pipeline with fixed approval outputs."""

    def __init__(self, approval_probabilities: list[float]) -> None:
        self._approval_probabilities = approval_probabilities

    def predict_proba(self, features) -> np.ndarray:
        assert len(features) == len(self._approval_probabilities)
        return np.array([[1 - p, p] for p in self._approval_probabilities])


def _payload(candidates: list[MLCandidateInput]) -> MLMatchingInput:
    return MLMatchingInput(
        applicant=MLApplicantInput(
            user_id=1, annual_income=Decimal("300000"), category="General"
        ),
        candidates=tuple(candidates),
    )


def _candidate(
    scheme_id: int,
    *,
    requested_amount: str,
    max_income_limit: str,
    max_loan_limit: str,
) -> MLCandidateInput:
    return MLCandidateInput(
        scheme_id=scheme_id,
        category="General",
        requested_amount=Decimal(requested_amount),
        max_loan_limit=Decimal(max_loan_limit),
        max_income_limit=Decimal(max_income_limit),
        annual_interest_rate=Decimal("8.0000"),
        tenure_months=60,
    )


def test_missing_artifact_reports_unavailable() -> None:
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    assert adapter.available is False


def test_predict_raises_when_unavailable() -> None:
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    with pytest.raises(MLUnavailableError):
        adapter.predict(_payload([_candidate(1, requested_amount="1", max_income_limit="1", max_loan_limit="1")]))


def test_predict_populates_both_scores_and_orders_rank_by_match_score() -> None:
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    # A well-matched scheme (same ratio as the applicant) and a skewed one,
    # deliberately given the *lower* approval probability so we can confirm
    # rank tracks match_score, not approval_probability.
    well_matched = _candidate(
        1, requested_amount="150000", max_income_limit="600000", max_loan_limit="300000"
    )
    skewed = _candidate(
        2, requested_amount="150000", max_income_limit="220000", max_loan_limit="3000000"
    )
    adapter._pipeline = _FakePipeline([0.2, 0.9])  # well_matched=0.2, skewed=0.9

    results = adapter.predict(_payload([well_matched, skewed]))

    by_scheme = {r.scheme_id: r for r in results}
    assert by_scheme[1].approval_probability == Decimal("0.2")
    assert by_scheme[2].approval_probability == Decimal("0.9")
    assert by_scheme[1].match_score > by_scheme[2].match_score
    assert by_scheme[1].rank == 1
    assert by_scheme[2].rank == 2
    for result in results:
        assert Decimal("0") <= result.match_score <= Decimal("1")


def test_tied_match_scores_break_ties_by_original_candidate_order() -> None:
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    identical_a = _candidate(
        10, requested_amount="150000", max_income_limit="600000", max_loan_limit="300000"
    )
    identical_b = _candidate(
        20, requested_amount="150000", max_income_limit="600000", max_loan_limit="300000"
    )
    adapter._pipeline = _FakePipeline([0.5, 0.5])

    results = adapter.predict(_payload([identical_a, identical_b]))

    assert results[0].match_score == results[1].match_score
    # Stable sort over candidates already in scheme.id order -> scheme 10 wins the tie.
    by_scheme = {r.scheme_id: r for r in results}
    assert by_scheme[10].rank == 1
    assert by_scheme[20].rank == 2
