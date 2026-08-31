"""Scheme and category query services."""

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session, contains_eager, joinedload

from app.models import Scheme, SchemeCategory


def list_categories(session: Session) -> list[SchemeCategory]:
    """Return every category in deterministic display order."""
    statement = select(SchemeCategory).order_by(
        SchemeCategory.category_name.asc(),
        SchemeCategory.id.asc(),
    )
    return list(session.scalars(statement))


def list_schemes(
    session: Session,
    *,
    category_id: int | None = None,
    category: str | None = None,
    max_income: Decimal | None = None,
    requested_amount: Decimal | None = None,
    is_active: bool | None = True,
) -> list[Scheme]:
    """Return schemes matching straightforward retrieval filters."""
    statement = (
        select(Scheme)
        .join(Scheme.category)
        .options(contains_eager(Scheme.category))
    )
    if category_id is not None:
        statement = statement.where(Scheme.category_id == category_id)
    if category is not None:
        statement = statement.where(
            func.lower(SchemeCategory.category_name) == category.casefold()
        )
    if max_income is not None:
        statement = statement.where(Scheme.max_income_limit >= max_income)
    if requested_amount is not None:
        statement = statement.where(Scheme.max_loan_limit >= requested_amount)
    if is_active is not None:
        statement = statement.where(Scheme.is_active.is_(is_active))

    statement = statement.order_by(Scheme.scheme_name.asc(), Scheme.id.asc())
    return list(session.scalars(statement))


def get_scheme(session: Session, scheme_id: int) -> Scheme | None:
    """Return one scheme with its category eagerly loaded."""
    statement = (
        select(Scheme)
        .options(joinedload(Scheme.category))
        .where(Scheme.id == scheme_id)
    )
    return session.scalar(statement)

