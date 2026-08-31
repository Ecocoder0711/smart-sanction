"""Explainable deterministic scheme eligibility rules."""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import Scheme, User
from app.schemas.eligibility import EligibilityResponse
from app.schemas.scheme import SchemeResponse


class SchemeNotFoundError(ValueError):
    """Raised when an eligibility request references no stored scheme."""


def check_eligibility(
    session: Session,
    applicant: User,
    *,
    scheme_id: int,
    requested_amount: Decimal,
) -> EligibilityResponse:
    """Evaluate every rule represented by the current user/scheme schema."""
    statement = (
        select(Scheme)
        .options(joinedload(Scheme.category))
        .where(Scheme.id == scheme_id)
    )
    scheme = session.scalar(statement)
    if scheme is None:
        raise SchemeNotFoundError

    return evaluate_scheme_eligibility(
        applicant,
        scheme,
        requested_amount=requested_amount,
    )


def evaluate_scheme_eligibility(
    applicant: User,
    scheme: Scheme,
    *,
    requested_amount: Decimal,
) -> EligibilityResponse:
    """Evaluate a loaded scheme so orchestration can reuse rules without re-querying."""
    checks = (
        (
            scheme.is_active,
            "Scheme is active",
            "Scheme is inactive",
        ),
        (
            applicant.category.strip().casefold()
            == scheme.category.category_name.strip().casefold(),
            "Applicant category is eligible",
            "Applicant category does not match the scheme category",
        ),
        (
            applicant.annual_income <= scheme.max_income_limit,
            "Annual income is within the scheme income limit",
            "Annual income exceeds the scheme income limit",
        ),
        (
            requested_amount > 0,
            "Requested amount is greater than zero",
            "Requested amount must be greater than zero",
        ),
        (
            requested_amount <= scheme.max_loan_limit,
            "Requested amount is within the maximum loan limit",
            "Requested amount exceeds the scheme maximum loan limit",
        ),
    )
    return EligibilityResponse(
        scheme=SchemeResponse.model_validate(scheme),
        requested_amount=requested_amount,
        eligible=all(passed for passed, _, _ in checks),
        reasons=[success if passed else failure for passed, success, failure in checks],
    )
