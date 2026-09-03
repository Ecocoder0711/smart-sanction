"""Loan application ORM model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import ApplicationStatus
from app.database.database import Base

if TYPE_CHECKING:
    from app.models.partner import ChannelPartner
    from app.models.scheme import Scheme
    from app.models.user import User


class Application(Base):
    """A user's application for a scheme through a channel partner."""

    __tablename__ = "applications"
    __table_args__ = (
        CheckConstraint("requested_amount > 0", name="ck_applications_requested_amount_positive"),
        CheckConstraint(
            "ml_match_score IS NULL OR ml_match_score BETWEEN 0 AND 1",
            name="ck_applications_ml_match_score_range",
        ),
        CheckConstraint(
            "ml_approval_probability IS NULL OR ml_approval_probability BETWEEN 0 AND 1",
            name="ck_applications_ml_approval_probability_range",
        ),
        CheckConstraint(
            "status IN ('draft', 'submitted', 'under_review', 'approved', "
            "'rejected', 'completed')",
            name="ck_applications_status_values",
        ),
        # A draft may still be deciding where to apply, but anything that has
        # left the applicant's hands must name a partner. Enforced in the
        # database so no code path can bypass it.
        CheckConstraint(
            "status = 'draft' OR partner_id IS NOT NULL",
            name="ck_applications_submitted_requires_partner",
        ),
        Index("ix_applications_user_id", "user_id"),
        Index("ix_applications_scheme_id", "scheme_id"),
        Index("ix_applications_partner_id", "partner_id"),
        Index("ix_applications_status", "status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    scheme_id: Mapped[int] = mapped_column(
        ForeignKey("schemes.id", ondelete="RESTRICT"),
        nullable=False,
    )
    # Nullable only so a draft can be saved before a partner is chosen; every
    # non-draft row is held to NOT NULL by the check constraint above.
    partner_id: Mapped[int | None] = mapped_column(
        ForeignKey("channel_partners.id", ondelete="RESTRICT"),
        nullable=True,
    )
    requested_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    ml_match_score: Mapped[Decimal | None] = mapped_column(Numeric(6, 5), nullable=True)
    ml_approval_probability: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 5),
        nullable=True,
    )
    application_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=ApplicationStatus.SUBMITTED.value,
        server_default=ApplicationStatus.SUBMITTED.value,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user: Mapped[User] = relationship(back_populates="applications")
    scheme: Mapped[Scheme] = relationship(back_populates="applications")
    partner: Mapped[ChannelPartner] = relationship(back_populates="applications")

