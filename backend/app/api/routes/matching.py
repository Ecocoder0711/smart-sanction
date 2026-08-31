"""Authenticated SMART-SANCTION matching orchestration endpoint."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import User
from app.schemas.matching import MatchRequest, MatchResponse
from app.services import matching_service

router = APIRouter(tags=["Matching"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post(
    "/api/match",
    response_model=MatchResponse,
    summary="Find deterministic scheme matches",
    description=(
        "Uses the Bearer-token user's stored profile to evaluate active schemes, "
        "calculate repayment details, and find nearby available partners. ML is "
        "optional and unavailable by default; no scores are fabricated."
    ),
    responses={401: {"description": "Missing or invalid access token."}},
)
def match(
    payload: MatchRequest,
    session: DatabaseSession,
    current_user: CurrentUser,
) -> MatchResponse:
    """Return eligible scheme candidates without persisting transient results."""
    return matching_service.match_schemes(session, current_user, payload)
