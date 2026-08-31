"""Scheme and scheme-category schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class SchemeCategoryResponse(BaseModel):
    """Scheme category representation."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    category_name: str
    description: str | None
    created_at: datetime


class SchemeResponse(BaseModel):
    """Concessional scheme representation."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    scheme_name: str
    category_id: int
    category: SchemeCategoryResponse
    max_loan_limit: Decimal = Field(ge=0, max_digits=14, decimal_places=2)
    interest_rate: Decimal = Field(ge=0, max_digits=7, decimal_places=4)
    moratorium_months: int = Field(ge=0)
    max_income_limit: Decimal = Field(ge=0, max_digits=14, decimal_places=2)
    description: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class SchemeListResponse(BaseModel):
    """Paginated-ready scheme collection response."""

    items: list[SchemeResponse]
    total: int = Field(ge=0)
