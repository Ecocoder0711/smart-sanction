"""Authenticated deterministic eligibility API route."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import User
from app.schemas.eligibility import EligibilityRequest, EligibilityResponse
from app.services import eligibility_service

router = APIRouter(prefix="/api/eligibility", tags=["Eligibility"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post(
    "/check",
    response_model=EligibilityResponse,
    summary="Check scheme eligibility",
    description=(
        "Evaluates active status, exact category compatibility, annual income, "
        "and requested amount for the Bearer token user. No ML is used."
    ),
    responses={
        400: {"description": "The authenticated user's profile is incomplete."},
        401: {"description": "Missing or invalid access token."},
        404: {"description": "Scheme not found."},
    },
)
def check_eligibility(
    payload: EligibilityRequest,
    session: DatabaseSession,
    current_user: CurrentUser,
) -> EligibilityResponse:
    """Return an explainable result without creating an application."""
    try:
        return eligibility_service.check_eligibility(
            session,
            current_user,
            scheme_id=payload.scheme_id,
            requested_amount=payload.requested_amount,
        )
    except eligibility_service.ProfileIncompleteError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Profile is incomplete",
                "missing_fields": exc.missing_fields,
            },
        ) from None
    except eligibility_service.SchemeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheme not found",
        ) from None

