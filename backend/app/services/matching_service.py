"""Orchestration for deterministic matching and the optional ML extension point."""

from collections.abc import Sequence
from decimal import Decimal

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import Scheme, User
from app.schemas.eligibility import EligibilityResponse
from app.schemas.matching import (
    CandidateEligibility,
    MatchCandidate,
    MatchRequest,
    MatchResponse,
    MLResult,
)
from app.schemas.partner import RecommendedPartnerResponse
from app.services import (
    calculator_service,
    eligibility_service,
    partner_service,
    scheme_service,
)
from app.services.ml import (
    MLApplicantInput,
    MLCandidateInput,
    MLCandidatePrediction,
    MLMatchingInput,
    MLUnavailableError,
    MatchingEngine,
)


def _partner_results(
    session: Session,
    user: User,
) -> tuple[list[RecommendedPartnerResponse], str]:
    """Return reusable nearby partners plus a frontend-friendly explanation."""
    settings = get_settings()
    try:
        partners = partner_service.recommend_partners_for_user(session, user)
    except partner_service.UserLocationRequiredError:
        return [], (
            "User location is not configured; nearby partner recommendations "
            "are unavailable."
        )
    if not partners:
        return [], (
            "No available partners were found within "
            f"{settings.recommended_partner_radius_km:g} km."
        )
    return partners, (
        f"{len(partners)} available partner(s) found within "
        f"{settings.recommended_partner_radius_km:g} km, ordered by distance."
    )


def _ml_payload(
    user: User,
    schemes: Sequence[Scheme],
    payload: MatchRequest,
) -> MLMatchingInput:
    """Map persisted deterministic candidates into the documented ML contract."""
    return MLMatchingInput(
        applicant=MLApplicantInput(
            user_id=user.id,
            annual_income=user.annual_income,
            category=user.category,
        ),
        candidates=tuple(
            MLCandidateInput(
                scheme_id=scheme.id,
                category=scheme.category.category_name,
                requested_amount=payload.requested_amount,
                max_loan_limit=scheme.max_loan_limit,
                max_income_limit=scheme.max_income_limit,
                annual_interest_rate=scheme.interest_rate,
                tenure_months=payload.tenure_months,
            )
            for scheme in schemes
        ),
    )


def _prediction_map(
    user: User,
    schemes: Sequence[Scheme],
    payload: MatchRequest,
    engine: MatchingEngine | None,
) -> tuple[str, dict[int, MLCandidatePrediction]]:
    """Call ML only when both configuration and a ready implementation allow it."""
    if not get_settings().ml_available or engine is None or not engine.available:
        return "unavailable", {}
    try:
        predictions = engine.predict(_ml_payload(user, schemes, payload))
    except MLUnavailableError:
        return "unavailable", {}
    return "available", {item.scheme_id: item for item in predictions}


def _candidate_sort_key(candidate: MatchCandidate) -> tuple[int, Decimal]:
    """Rank scored candidates by match_score descending; unscored ones last."""
    if candidate.ml is not None and candidate.ml.match_score is not None:
        return (0, -candidate.ml.match_score)
    return (1, Decimal(0))


def match_schemes(
    session: Session,
    user: User,
    payload: MatchRequest,
    *,
    ml_engine: MatchingEngine | None = None,
) -> MatchResponse:
    """Compose eligibility, finance, proximity, and optional ML results."""
    active_schemes = sorted(
        scheme_service.list_schemes(session, is_active=True),
        key=lambda scheme: scheme.id,
    )
    eligible: list[tuple[Scheme, EligibilityResponse]] = []
    for scheme in active_schemes:
        result = eligibility_service.evaluate_scheme_eligibility(
            user,
            scheme,
            requested_amount=payload.requested_amount,
        )
        if result.eligible:
            eligible.append((scheme, result))

    partners, partner_message = _partner_results(session, user)
    eligible_schemes = [scheme for scheme, _ in eligible]
    ml_status, predictions = _prediction_map(
        user,
        eligible_schemes,
        payload,
        ml_engine,
    )

    candidates: list[MatchCandidate] = []
    for scheme, eligibility in eligible:
        prediction = predictions.get(scheme.id)
        candidates.append(
            MatchCandidate(
                scheme=eligibility.scheme,
                eligibility=CandidateEligibility(
                    eligible=True,
                    reasons=eligibility.reasons,
                ),
                requested_amount=payload.requested_amount,
                financial=calculator_service.calculate_loan(
                    principal=payload.requested_amount,
                    annual_interest_rate=scheme.interest_rate,
                    tenure_months=payload.tenure_months,
                ),
                partners=partners,
                partner_message=partner_message,
                ml=(
                    MLResult(
                        match_score=prediction.match_score,
                        approval_probability=prediction.approval_probability,
                        rank=prediction.rank,
                    )
                    if prediction is not None
                    else None
                ),
            )
        )

    # Order by match_score (applicant-to-scheme financial fit) when ML
    # supplied one; candidates without a score (ML unavailable, or that
    # scheme had no prediction) keep their original scheme.id order.
    # list.sort() is stable, and `candidates` already arrives in scheme.id
    # order, so this is also the deterministic tie-break for equal scores.
    candidates.sort(key=_candidate_sort_key)

    count = len(candidates)
    message = (
        f"Found {count} eligible scheme candidate(s)."
        if count
        else "No matching scheme was found for the requested amount and profile."
    )
    return MatchResponse(
        requested_amount=payload.requested_amount,
        tenure_months=payload.tenure_months,
        candidate_count=count,
        message=message,
        candidates=candidates,
        ml_status=ml_status,
    )
