"""Explainable deterministic scheme eligibility rules."""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.enums import GenderEligibility, SchemeCategoryEligibility
from app.models import Scheme, User
from app.schemas.eligibility import EligibilityResponse
from app.schemas.scheme import SchemeResponse
from app.schemas.user import PROFILE_REQUIRED_FIELDS


class SchemeNotFoundError(ValueError):
    """Raised when an eligibility request references no stored scheme."""


class ProfileIncompleteError(ValueError):
    """Raised when an applicant has not supplied the required profile fields."""

    def __init__(self, missing_fields: list[str]) -> None:
        self.missing_fields = missing_fields
        super().__init__(
            "Profile is incomplete: " + ", ".join(missing_fields)
        )


def missing_profile_fields(applicant: User) -> list[str]:
    """Return the required profile fields this applicant has not supplied."""
    return [
        field_name
        for field_name in PROFILE_REQUIRED_FIELDS
        if getattr(applicant, field_name) is None
    ]


def require_complete_profile(applicant: User) -> None:
    """Refuse evaluation while any required profile field is still missing.

    Deliberately raises instead of substituting a default: a placeholder
    income, category, or gender would silently produce wrong eligibility
    results and would leak into the ML feature vectors.
    """
    missing = missing_profile_fields(applicant)
    if missing:
        raise ProfileIncompleteError(missing)


def check_eligibility(
    session: Session,
    applicant: User,
    *,
    scheme_id: int,
    requested_amount: Decimal,
) -> EligibilityResponse:
    """Evaluate every rule represented by the current user/scheme schema."""
    require_complete_profile(applicant)
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
    scheme_category = SchemeCategoryEligibility(
        scheme.category.category_name.strip().upper()
    )
    applicant_category = applicant.category.strip().upper()
    scheme_gender = GenderEligibility(scheme.gender_eligibility.strip().upper())
    applicant_gender = applicant.gender.strip().upper()
    checks = (
        (
            scheme.is_active,
            "Scheme is active",
            "Scheme is inactive",
        ),
        (
            scheme_category is SchemeCategoryEligibility.ANY
            or applicant_category == scheme_category.value,
            "Applicant category is eligible",
            "Applicant category does not match the scheme category",
        ),
        (
            scheme_gender is GenderEligibility.ANY
            or applicant_gender == scheme_gender.value,
            "Applicant gender is eligible",
            "Applicant gender does not match the scheme gender requirement",
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
