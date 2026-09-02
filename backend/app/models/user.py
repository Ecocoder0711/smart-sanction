"""User ORM model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, Index, Numeric, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import Gender
from app.database.database import Base

if TYPE_CHECKING:
    from app.models.application import Application


class User(Base):
    """A SMART-SANCTION applicant."""

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("annual_income >= 0", name="ck_users_annual_income_non_negative"),
        CheckConstraint(
            "category IN ('SC', 'ST', 'OBC', 'GENERAL')",
            name="ck_users_category_values",
        ),
        CheckConstraint(
            "gender IN ('MALE', 'FEMALE', 'OTHER')",
            name="ck_users_gender_values",
        ),
        CheckConstraint(
            "latitude IS NULL OR latitude BETWEEN -90 AND 90",
            name="ck_users_latitude_range",
        ),
        CheckConstraint(
            "longitude IS NULL OR longitude BETWEEN -180 AND 180",
            name="ck_users_longitude_range",
        ),
        UniqueConstraint("phone", name="uq_users_phone"),
        Index("ix_users_category", "category"),
        Index("ix_users_gender", "gender"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    phone: Mapped[str] = mapped_column(String(15), nullable=False)
    annual_income: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    gender: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default=Gender.OTHER.value,
        server_default=Gender.OTHER.value,
    )
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
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

    applications: Mapped[list[Application]] = relationship(back_populates="user")
