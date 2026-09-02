"""Deterministic cosine-similarity scoring between an applicant and a scheme.

Pure, stateless vector math: no trained artifact, no fitting step, nothing
request-dependent. Kept separate from RandomForestAdapter because it needs
none of that adapter's state; it is called from there (see
random_forest_engine.py) purely so match_score stays gated behind the same
ML_AVAILABLE / engine-availability path as approval_probability, matching
this prototype's existing ML architecture (see docs/ml-integration.md).
"""

from __future__ import annotations

from collections.abc import Sequence

from sklearn.metrics.pairwise import cosine_similarity

from app.services.ml.contracts import MLApplicantInput, MLCandidateInput

# Prototype scaling bounds, NOT fit from data. Chosen to cover the ranges
# actually present in the current synthetic dataset with headroom, so both
# vector dimensions land in a comparable, sub-2.0 numeric range regardless
# of which candidates appear in a given request:
#   - backend/seed/schemes.py:      max_income_limit ~2.2L-15L,
#                                    max_loan_limit   ~2L-30L
#   - data/synthetic/beneficiaries.csv (via data/ml/train_random_forest.py):
#                                    annual_income      up to ~20L
#                                    desired_loan_amount up to ~35L
# These are fixed, request-independent divisors so a scheme's score cannot
# shift based on which other schemes happen to be in the same request.
# Revisit once a real government scheme dataset replaces the synthetic seed.
INCOME_SCALE = 2_000_000
LOAN_SCALE = 4_000_000


def _scaled_vector(income: float, loan_amount: float) -> list[float]:
    """Scale one (income, loan-amount) pair into the shared comparison space."""
    return [income / INCOME_SCALE, loan_amount / LOAN_SCALE]


def compute_similarity_scores(
    applicant: MLApplicantInput,
    candidates: Sequence[MLCandidateInput],
) -> list[float]:
    """Return one cosine-similarity fraction in [0, 1] per candidate.

    Pairs [annual_income, requested_amount] against each scheme's
    [max_income_limit, max_loan_limit] to measure how closely the
    applicant's income-to-request ratio matches the scheme's
    income-limit-to-loan-limit ratio. Never raises: candidates is returned
    empty for an empty input, and any unexpected failure yields 0.0 (no
    similarity signal) for every candidate rather than breaking prediction.
    """
    if not candidates:
        return []

    try:
        applicant_vectors = [
            _scaled_vector(float(applicant.annual_income), float(candidate.requested_amount))
            for candidate in candidates
        ]
        scheme_vectors = [
            _scaled_vector(float(candidate.max_income_limit), float(candidate.max_loan_limit))
            for candidate in candidates
        ]
        # cosine_similarity is undefined for an all-zero vector; scikit-learn's
        # internal normalization leaves such a vector as zero rather than
        # raising, so this naturally yields 0.0 similarity for that candidate.
        return [
            float(cosine_similarity([a], [s])[0][0])
            for a, s in zip(applicant_vectors, scheme_vectors)
        ]
    except (ValueError, ArithmeticError, TypeError):
        return [0.0] * len(candidates)
