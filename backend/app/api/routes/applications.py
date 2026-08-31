"""Authenticated, owner-scoped application API routes."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.core.enums import ApplicationStatus
from app.database.session import get_db
from app.models import User
from app.schemas.application import (
    ApplicationCreate,
    ApplicationListResponse,
    ApplicationResponse,
)
from app.services import application_service

router = APIRouter(prefix="/api/applications", tags=["Applications"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post(
    "",
    response_model=ApplicationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create own application",
    description=(
        "Creates a submitted application owned by the Bearer token user. No "
        "eligibility, approval, or ML decision is performed."
    ),
    responses={
        401: {"description": "Missing or invalid access token."},
        404: {"description": "Scheme or partner not found."},
    },
)
def create_application(
    payload: ApplicationCreate,
    session: DatabaseSession,
    current_user: CurrentUser,
) -> ApplicationResponse:
    """Create an application without accepting ownership from the client."""
    try:
        return application_service.create_application(session, current_user, payload)
    except application_service.SchemeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheme not found",
        ) from None
    except application_service.PartnerNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Partner not found",
        ) from None


@router.get(
    "",
    response_model=ApplicationListResponse,
    summary="List own applications",
    description=(
        "Returns only applications whose user_id matches the Bearer token subject. "
        "Client-provided ownership is never accepted."
    ),
    responses={401: {"description": "Missing or invalid access token."}},
)
def list_own_applications(
    session: DatabaseSession,
    current_user: CurrentUser,
    scheme_id: Annotated[
        int | None,
        Query(gt=0, description="Filter own applications by scheme ID."),
    ] = None,
    partner_id: Annotated[
        int | None,
        Query(gt=0, description="Filter own applications by partner ID."),
    ] = None,
    application_status: Annotated[
        ApplicationStatus | None,
        Query(alias="status", description="Filter own applications by status."),
    ] = None,
) -> ApplicationListResponse:
    """Return only the authenticated user's applications."""
    items = application_service.list_applications(
        session,
        owner_id=current_user.id,
        scheme_id=scheme_id,
        partner_id=partner_id,
        status=application_status,
    )
    return ApplicationListResponse(items=items, total=len(items))


@router.get(
    "/{application_id}",
    response_model=ApplicationResponse,
    summary="Get own application",
    description=(
        "Returns an application only when it belongs to the Bearer token user. "
        "Missing and other-user resources both return 404."
    ),
    responses={
        401: {"description": "Missing or invalid access token."},
        404: {"description": "Application not found."},
    },
)
def get_own_application(
    session: DatabaseSession,
    current_user: CurrentUser,
    application_id: Annotated[
        int,
        Path(gt=0, description="Application primary key."),
    ],
) -> ApplicationResponse:
    """Return an owned application or a non-enumerating 404."""
    application = application_service.get_application(
        session,
        application_id,
        owner_id=current_user.id,
    )
    if application is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Application not found",
        )
    return application

