"""Reusable authenticated-user API dependencies."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import TokenValidationError, decode_access_token
from app.database.session import get_db
from app.models import User

bearer_scheme = HTTPBearer(
    auto_error=False,
    bearerFormat="JWT",
    scheme_name="BearerAuth",
    description="JWT access token returned by POST /api/auth/login.",
)


def _authentication_error() -> HTTPException:
    """Build a consistent 401 response without exposing token details."""
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
    session: Annotated[Session, Depends(get_db)],
) -> User:
    """Decode a Bearer token and load its current database user."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _authentication_error()
    try:
        user_id = decode_access_token(credentials.credentials)
    except TokenValidationError:
        raise _authentication_error() from None

    user = session.get(User, user_id)
    if user is None:
        raise _authentication_error()
    return user

