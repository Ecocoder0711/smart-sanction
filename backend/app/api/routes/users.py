"""Authenticated current-user profile routes."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import User
from app.schemas.user import UserResponse, UserUpdate
from app.services import user_service

router = APIRouter(prefix="/api/users", tags=["Users"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get own profile",
    description="Returns only the profile identified by the Bearer token.",
    responses={401: {"description": "Missing or invalid access token."}},
)
def get_own_profile(current_user: CurrentUser) -> UserResponse:
    """Return the authenticated user's profile."""
    return current_user


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Update own profile",
    description=(
        "Updates only editable fields on the Bearer token owner. IDs, password "
        "hashes, and timestamps are never accepted."
    ),
    responses={
        401: {"description": "Missing or invalid access token."},
        409: {"description": "Phone number is already in use."},
    },
)
def update_own_profile(
    payload: UserUpdate,
    session: DatabaseSession,
    current_user: CurrentUser,
) -> UserResponse:
    """Update the authenticated user's safe profile fields."""
    try:
        return user_service.update_user(session, current_user, payload)
    except user_service.PhoneAlreadyInUseError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number is already in use",
        ) from None

