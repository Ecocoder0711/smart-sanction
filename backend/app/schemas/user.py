"""User request and response schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    computed_field,
    field_validator,
    model_validator,
)

from app.core.enums import ApplicantCategory, Gender

INDIAN_MOBILE_PATTERN = r"^(?:\+91|91)?[6-9]\d{9}$"

# Profile fields eligibility and ML require before they can run at all.
# Single source of truth for both profile_complete and the service-layer guard.
PROFILE_REQUIRED_FIELDS: tuple[str, ...] = ("annual_income", "category", "gender")


class UserBase(BaseModel):
    """Fields shared by user creation contracts.

    annual_income, category, and gender are optional so registration can
    complete with name/phone/password alone; the applicant supplies them
    afterwards through PUT /api/users/me. They stay strictly validated
    whenever a value is actually supplied, and no default is substituted --
    a missing value is stored as NULL, never as a placeholder.
    """

    full_name: str = Field(min_length=2, max_length=150)
    phone: str = Field(pattern=INDIAN_MOBILE_PATTERN, max_length=15)
    annual_income: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=14,
        decimal_places=2,
    )
    category: ApplicantCategory | None = None
    gender: Gender | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @field_validator("category", "gender", mode="before")
    @classmethod
    def normalize_enums(cls, value: object) -> object:
        """Accept harmless casing differences while keeping a strict value set."""
        return value.strip().upper() if isinstance(value, str) else value


class UserCreate(UserBase):
    """Create a user profile without accepting an unhashed password."""


class UserUpdate(BaseModel):
    """Update one or more editable user profile fields."""

    model_config = ConfigDict(extra="forbid")

    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    phone: str | None = Field(
        default=None,
        pattern=INDIAN_MOBILE_PATTERN,
        max_length=15,
    )
    annual_income: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=14,
        decimal_places=2,
    )
    category: ApplicantCategory | None = None
    gender: Gender | None = None
    state: str | None = Field(default=None, min_length=1, max_length=100)
    district: str | None = Field(default=None, min_length=1, max_length=100)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @field_validator("category", "gender", mode="before")
    @classmethod
    def normalize_enums(cls, value: object) -> object:
        """Normalize supplied enum strings before strict validation."""
        return value.strip().upper() if isinstance(value, str) else value

    @model_validator(mode="after")
    def require_at_least_one_field(self) -> "UserUpdate":
        """Reject an update payload that does not contain any fields."""
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided")
        required_fields = {"full_name", "phone", "annual_income", "category", "gender"}
        null_required_fields = [
            field_name
            for field_name in required_fields & self.model_fields_set
            if getattr(self, field_name) is None
        ]
        if null_required_fields:
            raise ValueError(
                f"Fields cannot be null: {', '.join(sorted(null_required_fields))}"
            )
        return self


class UserResponse(UserBase):
    """Public user representation; password hashes are never exposed."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    state: str | None = None
    district: str | None = None
    created_at: datetime
    updated_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def profile_complete(self) -> bool:
        """Report whether eligibility and matching can run for this user.

        Derived on every response rather than stored, so it can never drift
        out of sync with the underlying columns.
        """
        return all(
            getattr(self, field_name) is not None
            for field_name in PROFILE_REQUIRED_FIELDS
        )
