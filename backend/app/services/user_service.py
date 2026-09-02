"""Authenticated user profile services."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import User
from app.schemas.user import UserUpdate


class PhoneAlreadyInUseError(ValueError):
    """Raised when a profile update would violate phone uniqueness."""


def update_user(session: Session, user: User, payload: UserUpdate) -> User:
    """Update only explicitly supplied editable fields for the token owner."""
    changes = payload.model_dump(mode="json", exclude_unset=True)
    new_phone = changes.get("phone")
    if new_phone is not None and new_phone != user.phone:
        phone_owner = session.scalar(select(User).where(User.phone == new_phone))
        if phone_owner is not None:
            raise PhoneAlreadyInUseError

    for field_name, value in changes.items():
        setattr(user, field_name, value)
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise PhoneAlreadyInUseError from exc
    session.refresh(user)
    return user
