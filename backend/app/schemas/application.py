"""Loan application request and response schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.core.enums import ApplicationStatus


class ApplicationCreate(BaseModel):
    """Create an application for the authenticated user."""

    model_config = ConfigDict(extra="forbid")

    scheme_id: int = Field(gt=0)
    partner_id: int = Field(gt=0)
    requested_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)


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
    partner_id: int
    partner_name: str
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
