"""Channel partner ORM model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, DateTime, Index, Numeric, String, func, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.database import Base

if TYPE_CHECKING:
    from app.models.application import Application


class ChannelPartner(Base):
    """A participating bank branch or lending channel."""

    __tablename__ = "channel_partners"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="ck_partners_latitude_range"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="ck_partners_longitude_range"),
        CheckConstraint(
            "npa_percentage BETWEEN 0 AND 100",
            name="ck_partners_npa_percentage_range",
        ),
        CheckConstraint("quota_remaining >= 0", name="ck_partners_quota_non_negative"),
        Index("ix_channel_partners_is_active", "is_active"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    bank_name: Mapped[str] = mapped_column(String(150), nullable=False)
    branch_code: Mapped[str] = mapped_column(String(50), nullable=False)
    latitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    npa_percentage: Mapped[Decimal] = mapped_column(Numeric(7, 4), nullable=False)
    quota_remaining: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=true(),
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

    applications: Mapped[list[Application]] = relationship(back_populates="partner")

