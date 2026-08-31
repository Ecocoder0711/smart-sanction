"""Authenticated, owner-scoped loan-application services."""

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.enums import ApplicationStatus
from app.models import Application, ChannelPartner, Scheme, User
from app.schemas.application import ApplicationCreate, ApplicationResponse


class SchemeNotFoundError(ValueError):
    """Raised when an application references a nonexistent scheme."""


class PartnerNotFoundError(ValueError):
    """Raised when an application references a nonexistent partner."""


def _to_response(application: Application) -> ApplicationResponse:
    """Map an eagerly loaded application to its public response contract."""
    return ApplicationResponse(
        id=application.id,
        user_id=application.user_id,
        user_name=application.user.full_name,
        scheme_id=application.scheme_id,
        scheme_name=application.scheme.scheme_name,
        partner_id=application.partner_id,
        partner_name=application.partner.bank_name,
        requested_amount=application.requested_amount,
        ml_match_score=application.ml_match_score,
        ml_approval_probability=application.ml_approval_probability,
        application_date=application.application_date,
        status=application.status,
        created_at=application.created_at,
        updated_at=application.updated_at,
    )


def list_applications(
    session: Session,
    *,
    owner_id: int,
    scheme_id: int | None = None,
    partner_id: int | None = None,
    status: ApplicationStatus | None = None,
) -> list[ApplicationResponse]:
    """Return only applications owned by the authenticated user ID."""
    statement = (
        select(Application)
        .options(
            joinedload(Application.user),
            joinedload(Application.scheme),
            joinedload(Application.partner),
        )
        .where(Application.user_id == owner_id)
    )
    if scheme_id is not None:
        statement = statement.where(Application.scheme_id == scheme_id)
    if partner_id is not None:
        statement = statement.where(Application.partner_id == partner_id)
    if status is not None:
        statement = statement.where(Application.status == status.value)
    statement = statement.order_by(
        Application.application_date.desc(),
        Application.id.desc(),
    )
    return [_to_response(item) for item in session.scalars(statement)]


def get_application(
    session: Session,
    application_id: int,
    *,
    owner_id: int,
) -> ApplicationResponse | None:
    """Return an application only when its owner matches the token subject."""
    statement = (
        select(Application)
        .options(
            joinedload(Application.user),
            joinedload(Application.scheme),
            joinedload(Application.partner),
        )
        .where(
            Application.id == application_id,
            Application.user_id == owner_id,
        )
    )
    application = session.scalar(statement)
    return _to_response(application) if application is not None else None


def create_application(
    session: Session,
    owner: User,
    payload: ApplicationCreate,
) -> ApplicationResponse:
    """Create a submitted application owned exclusively by the token user."""
    if session.get(Scheme, payload.scheme_id) is None:
        raise SchemeNotFoundError
    if session.get(ChannelPartner, payload.partner_id) is None:
        raise PartnerNotFoundError

    application = Application(
        user_id=owner.id,
        scheme_id=payload.scheme_id,
        partner_id=payload.partner_id,
        requested_amount=payload.requested_amount,
        status=ApplicationStatus.SUBMITTED.value,
        ml_match_score=None,
        ml_approval_probability=None,
    )
    session.add(application)
    session.commit()
    application_id = application.id
    created = get_application(session, application_id, owner_id=owner.id)
    if created is None:  # Defensive invariant; the committed row must be owner-visible.
        raise RuntimeError("Created application could not be loaded")
    return created

