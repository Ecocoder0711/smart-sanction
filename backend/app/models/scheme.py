"""Concessional scheme ORM model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, String, Text, func, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import GenderEligibility
from app.database.database import Base

if TYPE_CHECKING:
    from app.models.application import Application
    from app.models.scheme_category import SchemeCategory


class Scheme(Base):
    """A government or concessional credit scheme definition."""

    __tablename__ = "schemes"
    __table_args__ = (
        CheckConstraint("max_loan_limit >= 0", name="ck_schemes_max_loan_non_negative"),
        CheckConstraint("interest_rate >= 0", name="ck_schemes_interest_rate_non_negative"),
        CheckConstraint("moratorium_months >= 0", name="ck_schemes_moratorium_non_negative"),
        CheckConstraint("max_income_limit >= 0", name="ck_schemes_max_income_non_negative"),
        CheckConstraint(
            "gender_eligibility IN ('ANY', 'MALE', 'FEMALE', 'OTHER')",
            name="ck_schemes_gender_eligibility_values",
        ),
        Index("ix_schemes_category_id", "category_id"),
        Index("ix_schemes_gender_eligibility", "gender_eligibility"),
        Index("ix_schemes_is_active", "is_active"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    scheme_name: Mapped[str] = mapped_column(String(200), nullable=False)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("scheme_categories.id", ondelete="RESTRICT"),
        nullable=False,
    )
    gender_eligibility: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default=GenderEligibility.ANY.value,
        server_default=GenderEligibility.ANY.value,
    )
    max_loan_limit: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    interest_rate: Mapped[Decimal] = mapped_column(Numeric(7, 4), nullable=False)
    moratorium_months: Mapped[int] = mapped_column(Integer, nullable=False)
    max_income_limit: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
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

    category: Mapped[SchemeCategory] = relationship(back_populates="schemes")
    applications: Mapped[list[Application]] = relationship(back_populates="scheme")
