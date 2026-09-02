"""Unit tests for RandomForestAdapter's orchestration of the two ML scores.

These tests stub out the trained pipeline (predict_proba) so they exercise
match_score/approval_probability/rank wiring deterministically, without
depending on the gitignored random_forest_v1.joblib artifact being present.
"""

import pickle
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


class _PicklableEstimator:
    """Module-level (therefore picklable) object satisfying the shape check."""

    def predict_proba(self, features) -> np.ndarray:
        return np.zeros((len(features), 2))


class _ExplodingPipeline:
    """Fails loudly if consulted; proves a call was skipped, not tolerated."""

    def predict_proba(self, features) -> np.ndarray:
        raise AssertionError(
            f"predict_proba must not be called (got {len(features)} rows)"
        )


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


# Each payload below is a corruption mode that was observed to raise a
# *different* exception type out of pickle (EOFError, IndexError, KeyError,
# ValueError, UnpicklingError...). They are parametrised together because the
# adapter's contract is the same for all of them: degrade, never raise.
@pytest.mark.parametrize(
    ("label", "payload"),
    [
        ("empty file", b""),
        ("single byte", b"\x80"),
        ("plain text", b"not a pickle at all, just prose"),
        ("repeated non-opcode byte", bytes([182]) * 4096),
        ("all zero bytes", bytes(4096)),
        ("all 0xFF bytes", b"\xff" * 4096),
        ("html error page", b"<html><body>404 Not Found</body></html>"),
        (
            "git-lfs pointer, not the model",
            b"version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 44\n",
        ),
    ],
)
def test_corrupt_artifact_degrades_instead_of_raising(
    tmp_path: Path,
    label: str,
    payload: bytes,
) -> None:
    artifact = tmp_path / "random_forest_v1.joblib"
    artifact.write_bytes(payload)

    adapter = RandomForestAdapter(artifact_path=artifact)

    assert adapter.available is False, label


def test_truncated_real_shaped_artifact_degrades(tmp_path: Path) -> None:
    """Half a valid pickle stream: a plausible partial download or copy."""
    artifact = tmp_path / "random_forest_v1.joblib"
    full = pickle.dumps({"payload": list(range(10_000))})
    artifact.write_bytes(full[: len(full) // 2])

    assert RandomForestAdapter(artifact_path=artifact).available is False


@pytest.mark.parametrize(
    "wrong_object",
    [
        {"not": "a pipeline"},
        [1, 2, 3],
        42,
        "a string, not an estimator",
    ],
)
def test_valid_pickle_of_wrong_object_reports_unavailable(
    tmp_path: Path,
    wrong_object: object,
) -> None:
    """Unpickles cleanly but has no predict_proba.

    Without the shape check this reported available=True and only failed once
    a request reached predict(), i.e. as an HTTP 500 rather than a graceful
    ml_status of "unavailable".
    """
    artifact = tmp_path / "random_forest_v1.joblib"
    artifact.write_bytes(pickle.dumps(wrong_object))

    assert RandomForestAdapter(artifact_path=artifact).available is False


def test_directory_in_place_of_artifact_degrades(tmp_path: Path) -> None:
    assert RandomForestAdapter(artifact_path=tmp_path).available is False


def test_object_exposing_predict_proba_is_accepted(tmp_path: Path) -> None:
    """The shape check must not reject a legitimate estimator.

    Guards against tightening the check into something that only recognises
    sklearn's concrete Pipeline class and rejects a valid replacement model.
    """
    artifact = tmp_path / "random_forest_v1.joblib"
    artifact.write_bytes(pickle.dumps(_PicklableEstimator()))

    assert RandomForestAdapter(artifact_path=artifact).available is True


def test_predict_raises_when_unavailable() -> None:
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    with pytest.raises(MLUnavailableError):
        adapter.predict(_payload([_candidate(1, requested_amount="1", max_income_limit="1", max_loan_limit="1")]))


def test_predict_returns_empty_without_calling_the_model_for_no_candidates() -> None:
    """Regression: a zero-row frame makes sklearn raise, which became a 500.

    Deterministic eligibility legitimately matches nothing for some requests,
    and that must stay a valid empty result rather than an error.
    """
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    adapter._pipeline = _ExplodingPipeline()

    assert adapter.predict(_payload([])) == []


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
