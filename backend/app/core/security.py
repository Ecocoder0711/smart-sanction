"""Password hashing and JWT access-token primitives."""

from datetime import datetime, timedelta, timezone

import jwt
from jwt import ExpiredSignatureError
from jwt import InvalidTokenError as PyJWTInvalidTokenError
from pwdlib import PasswordHash
from pwdlib.exceptions import PwdlibError

from app.core.config import get_settings

_password_hash = PasswordHash.recommended()


class TokenValidationError(ValueError):
    """Raised when an access token cannot establish a valid user subject."""


def hash_password(password: str) -> str:
    """Hash a raw password with pwdlib's recommended Argon2 configuration."""
    return _password_hash.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    """Safely verify a raw password; null or malformed hashes never authenticate."""
    if not password_hash:
        return False
    try:
        return _password_hash.verify(password, password_hash)
    except PwdlibError:
        return False


def _jwt_configuration() -> tuple[str, str, int]:
    """Return validated JWT signing configuration without exposing the secret."""
    settings = get_settings()
    secret = (settings.jwt_secret_key or "").strip()
    if len(secret) < 32:
        raise RuntimeError(
            "JWT_SECRET_KEY must be configured with at least 32 characters"
        )
    return secret, settings.jwt_algorithm, settings.access_token_expire_minutes


def create_access_token(
    subject: int,
    *,
    expires_delta: timedelta | None = None,
) -> str:
    """Create a signed JWT access token whose subject is a user primary key."""
    secret, algorithm, default_expiry_minutes = _jwt_configuration()
    now = datetime.now(timezone.utc)
    expiry = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=default_expiry_minutes)
    )
    payload = {
        "sub": str(subject),
        "type": "access",
        "iat": now,
        "exp": expiry,
    }
    return jwt.encode(payload, secret, algorithm=algorithm)


def decode_access_token(token: str) -> int:
    """Validate an access token and return its positive integer user subject."""
    secret, algorithm, _ = _jwt_configuration()
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=[algorithm],
            options={"require": ["sub", "iat", "exp"]},
        )
        subject = payload.get("sub")
        if payload.get("type") != "access" or not isinstance(subject, str):
            raise TokenValidationError("Invalid token claims")
        user_id = int(subject)
        if user_id <= 0 or str(user_id) != subject:
            raise TokenValidationError("Invalid token subject")
        return user_id
    except (ExpiredSignatureError, PyJWTInvalidTokenError, TypeError, ValueError) as exc:
        raise TokenValidationError("Invalid or expired access token") from exc

