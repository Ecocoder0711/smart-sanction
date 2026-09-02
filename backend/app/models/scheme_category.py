"""Scheme category ORM model."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.database import Base

if TYPE_CHECKING:
    from app.models.scheme import Scheme


class SchemeCategory(Base):
    """A demographic or program category used to group schemes."""

    __tablename__ = "scheme_categories"
    __table_args__ = (
        CheckConstraint(
            "category_name IN ('ANY', 'SC', 'ST', 'OBC', 'GENERAL')",
            name="ck_scheme_categories_name_values",
        ),
        UniqueConstraint("category_name", name="uq_scheme_categories_category_name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category_name: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    schemes: Mapped[list[Scheme]] = relationship(back_populates="category")
