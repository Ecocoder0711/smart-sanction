"""Controlled internal lifecycle transitions for loan applications."""

from types import MappingProxyType

from sqlalchemy.orm import Session

from app.core.enums import ApplicationStatus
from app.models import Application

ALLOWED_TRANSITIONS = MappingProxyType(
    {
        ApplicationStatus.SUBMITTED: frozenset({ApplicationStatus.UNDER_REVIEW}),
        ApplicationStatus.UNDER_REVIEW: frozenset(
            {ApplicationStatus.APPROVED, ApplicationStatus.REJECTED}
        ),
        ApplicationStatus.APPROVED: frozenset({ApplicationStatus.COMPLETED}),
        ApplicationStatus.REJECTED: frozenset(),
        ApplicationStatus.COMPLETED: frozenset(),
    }
)


class InvalidStatusTransitionError(ValueError):
    """Raised when a requested application lifecycle transition is not allowed."""

    def __init__(
        self,
        current_status: ApplicationStatus,
        requested_status: ApplicationStatus,
    ) -> None:
        self.current_status = current_status
        self.requested_status = requested_status
        super().__init__(
            f"Cannot transition application from {current_status.value} "
            f"to {requested_status.value}"
        )


def allowed_transitions(status: ApplicationStatus) -> frozenset[ApplicationStatus]:
    """Return the immutable set of states reachable in one transition."""
    return ALLOWED_TRANSITIONS[status]


def transition_application(
    session: Session,
    application: Application,
    new_status: ApplicationStatus,
) -> Application:
    """Persist one valid internal transition; no public user route calls this."""
    current_status = ApplicationStatus(application.status)
    if new_status not in allowed_transitions(current_status):
        raise InvalidStatusTransitionError(current_status, new_status)

    application.status = new_status.value
    session.add(application)
    session.commit()
    session.refresh(application)
    return application
