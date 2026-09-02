"""Authenticated SMART-SANCTION matching orchestration endpoint."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import User
from app.schemas.matching import MatchRequest, MatchResponse
from app.services import eligibility_service, matching_service
from app.services.ml.contracts import MatchingEngine
from app.services.ml.random_forest_engine import get_ml_engine

router = APIRouter(tags=["Matching"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]
MlEngine = Annotated[MatchingEngine, Depends(get_ml_engine)]


@router.post(
    "/api/match",
    response_model=MatchResponse,
    summary="Find deterministic scheme matches",
    description=(
        "Uses the Bearer-token user's stored profile to evaluate active schemes, "
        "calculate repayment details, and find nearby available partners. ML is "
        "optional and unavailable by default; no scores are fabricated."
    ),
    responses={
        400: {"description": "The authenticated user's profile is incomplete."},
        401: {"description": "Missing or invalid access token."},
    },
)
def match(
    payload: MatchRequest,
    session: DatabaseSession,
    current_user: CurrentUser,
    ml_engine: MlEngine,
) -> MatchResponse:
    """Return eligible scheme candidates without persisting transient results."""
    try:
        return matching_service.match_schemes(
            session,
            current_user,
            payload,
            ml_engine=ml_engine,
        )
    except eligibility_service.ProfileIncompleteError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Profile is incomplete",
                "missing_fields": exc.missing_fields,
            },
        ) from None
