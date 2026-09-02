"""Unit tests for the pure cosine-similarity scoring function."""

from decimal import Decimal

from app.services.ml.contracts import MLApplicantInput, MLCandidateInput
from app.services.ml.similarity import compute_similarity_scores


def _applicant(annual_income: str, category: str = "General") -> MLApplicantInput:
    return MLApplicantInput(user_id=1, annual_income=Decimal(annual_income), category=category)


def _candidate(
    *,
    scheme_id: int = 1,
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


def test_empty_candidate_list_returns_empty_scores() -> None:
    assert compute_similarity_scores(_applicant("300000"), []) == []


def test_proportional_vectors_score_very_high() -> None:
    """A scheme whose limits are the same multiple of the applicant's profile."""
    applicant = _applicant("300000")
    # Scheme limits are exactly 2x the applicant's income/request -- same
    # ratio, so the vectors point in the same direction.
    candidate = _candidate(
        requested_amount="150000",
        max_income_limit="600000",
        max_loan_limit="300000",
    )
    scores = compute_similarity_scores(applicant, [candidate])
    assert len(scores) == 1
    assert scores[0] > 0.999


def test_different_ratios_score_lower() -> None:
    """A scheme skewed the opposite way should score well below a matched one."""
    applicant = _applicant("300000")
    matched = _candidate(
        scheme_id=1,
        requested_amount="150000",
        max_income_limit="600000",
        max_loan_limit="300000",
    )
    skewed = _candidate(
        scheme_id=2,
        requested_amount="150000",
        max_income_limit="220000",
        max_loan_limit="3000000",
    )
    matched_score, skewed_score = compute_similarity_scores(applicant, [matched, skewed])
    assert skewed_score < matched_score


def test_scores_always_within_unit_range() -> None:
    applicant = _applicant("2000000")
    candidates = [
        _candidate(scheme_id=1, requested_amount="20000", max_income_limit="220000", max_loan_limit="200000"),
        _candidate(scheme_id=2, requested_amount="3500000", max_income_limit="1500000", max_loan_limit="3000000"),
        _candidate(scheme_id=3, requested_amount="1", max_income_limit="1", max_loan_limit="1"),
    ]
    for score in compute_similarity_scores(applicant, candidates):
        assert 0.0 <= score <= 1.0


def test_zero_scheme_vector_does_not_raise() -> None:
    """A degenerate all-zero scheme vector must not crash the calculation.

    requested_amount is contractually gt=0, so only a scheme's own limits
    (both ge=0) can realistically produce an all-zero vector -- e.g. a
    misconfigured scheme with no income or loan limit set.
    """
    applicant = _applicant("0")
    candidate = _candidate(
        requested_amount="50000",
        max_income_limit="0",
        max_loan_limit="0",
    )
    scores = compute_similarity_scores(applicant, [candidate])
    assert scores == [0.0]
