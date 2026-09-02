"""Authentication business logic and persistence."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models import User
from app.schemas.auth import PasswordChangeRequest, RegisterRequest


class PhoneAlreadyRegisteredError(ValueError):
    """Raised when registration attempts to reuse a phone number."""


class InvalidCurrentPasswordError(ValueError):
    """Raised when password-change verification fails."""


def get_user_by_phone(session: Session, phone: str) -> User | None:
    """Return the user registered with an exact phone number."""
    return session.scalar(select(User).where(User.phone == phone))


def register_user(session: Session, payload: RegisterRequest) -> User:
    """Create a user with an Argon2 password hash and a unique phone number."""
    if get_user_by_phone(session, payload.phone) is not None:
        raise PhoneAlreadyRegisteredError

    values = payload.model_dump(mode="json", exclude={"password"})
    user = User(
        **values,
        password_hash=hash_password(payload.password.get_secret_value()),
    )
    session.add(user)
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise PhoneAlreadyRegisteredError from exc
    session.refresh(user)
    return user


def authenticate_user(session: Session, phone: str, password: str) -> User | None:
    """Return a user only when phone and password validate successfully."""
    user = get_user_by_phone(session, phone)
    if user is None or not verify_password(password, user.password_hash):
        return None
    return user


def change_password(
    session: Session,
    user: User,
    payload: PasswordChangeRequest,
) -> None:
    """Verify the current password and persist a new Argon2 hash."""
    current_password = payload.current_password.get_secret_value()
    if not verify_password(current_password, user.password_hash):
        raise InvalidCurrentPasswordError
    user.password_hash = hash_password(payload.new_password.get_secret_value())
    session.commit()
