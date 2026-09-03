"""Loan application request and response schemas."""

from datetime import datetime
from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.enums import ApplicationStatus


# The only two states a client may create directly. Everything after
# SUBMITTED is an internal review outcome and is reached through the workflow
# service, never by asking for it at creation time.
CLIENT_CREATABLE_STATUSES: Final = (
    ApplicationStatus.DRAFT,
    ApplicationStatus.SUBMITTED,
)


class ApplicationCreate(BaseModel):
    """Create an application for the authenticated user.

    Defaults to SUBMITTED so existing callers are unaffected by drafts being
    added. A draft may omit partner_id -- the applicant may still be choosing
    -- but a submitted application must name one.
    """

    model_config = ConfigDict(extra="forbid")

    scheme_id: int = Field(gt=0)
    partner_id: int | None = Field(default=None, gt=0)
    requested_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    status: Literal[ApplicationStatus.DRAFT, ApplicationStatus.SUBMITTED] = (
        ApplicationStatus.SUBMITTED
    )

    @model_validator(mode="after")
    def submitted_requires_partner(self) -> "ApplicationCreate":
        """Refuse a submitted application with nowhere to send it."""
        if self.status is not ApplicationStatus.DRAFT and self.partner_id is None:
            raise ValueError("partner_id is required unless status is 'draft'")
        return self


class ApplicationStatusUpdate(BaseModel):
    """Update an application to a controlled lifecycle status."""

    status: ApplicationStatus


class ApplicationResponse(BaseModel):
    """Loan application representation with optional future ML outputs."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    user_name: str
    scheme_id: int
    scheme_name: str
    # Null on a draft saved before a partner was chosen.
    partner_id: int | None = None
    partner_name: str | None = None
    requested_amount: Decimal
    ml_match_score: Decimal | None = Field(default=None, ge=0, le=1)
    ml_approval_probability: Decimal | None = Field(default=None, ge=0, le=1)
    application_date: datetime
    status: ApplicationStatus
    created_at: datetime
    updated_at: datetime


class ApplicationListResponse(BaseModel):
    """Paginated-ready application collection response."""

    items: list[ApplicationResponse]
    total: int = Field(ge=0)
