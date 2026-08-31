"""Registration, login, current-user, and password routes."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.core.security import create_access_token
from app.database.session import get_db
from app.models import User
from app.schemas.auth import LoginRequest, PasswordChangeRequest, RegisterRequest, TokenResponse
from app.schemas.user import UserResponse
from app.services import auth_service

router = APIRouter(prefix="/api/auth", tags=["Authentication"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a user",
    description="Creates a user and stores only an Argon2 password hash.",
    responses={409: {"description": "Phone number is already registered."}},
)
def register(payload: RegisterRequest, session: DatabaseSession) -> UserResponse:
    """Register a unique phone-number account."""
    try:
        return auth_service.register_user(session, payload)
    except auth_service.PhoneAlreadyRegisteredError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number is already registered",
        ) from None


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login",
    description="Verifies phone/password credentials and returns a Bearer JWT.",
    responses={401: {"description": "Invalid credentials."}},
)
def login(payload: LoginRequest, session: DatabaseSession) -> TokenResponse:
    """Authenticate without revealing which credential was incorrect."""
    user = auth_service.authenticate_user(
        session,
        payload.phone,
        payload.password.get_secret_value(),
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(
        access_token=create_access_token(user.id),
        user=UserResponse.model_validate(user),
    )


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get authenticated user",
    description="Returns the profile identified only by the Bearer token subject.",
    responses={401: {"description": "Missing or invalid access token."}},
)
def get_authenticated_user(current_user: CurrentUser) -> UserResponse:
    """Return the token owner without accepting a client user ID."""
    return current_user


@router.put(
    "/password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Change password",
    description="Verifies the current password before storing a new Argon2 hash.",
    responses={401: {"description": "Invalid token or current password."}},
)
def update_password(
    payload: PasswordChangeRequest,
    session: DatabaseSession,
    current_user: CurrentUser,
) -> Response:
    """Change only the authenticated user's password."""
    try:
        auth_service.change_password(session, current_user, payload)
    except auth_service.InvalidCurrentPasswordError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        ) from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)

