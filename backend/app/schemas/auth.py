"""Future authentication API contracts only; no auth logic is implemented."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, model_validator

from app.schemas.user import INDIAN_MOBILE_PATTERN, UserBase, UserResponse


class RegisterRequest(UserBase):
    """Future registration payload containing a raw password for hashing."""

    model_config = ConfigDict(extra="forbid")

    password: SecretStr = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    """Future phone/password login payload."""

    phone: str = Field(pattern=INDIAN_MOBILE_PATTERN, max_length=15)
    password: SecretStr = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    """Future JWT access-token response."""

    access_token: str
    token_type: Literal["bearer"] = "bearer"
    user: UserResponse


class AuthenticatedUserResponse(BaseModel):
    """Future authenticated-user response envelope."""

    user: UserResponse


class PasswordChangeRequest(BaseModel):
    """Authenticated password-change payload."""

    model_config = ConfigDict(extra="forbid")

    current_password: SecretStr = Field(min_length=8, max_length=128)
    new_password: SecretStr = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def passwords_must_differ(self) -> "PasswordChangeRequest":
        """Reject a no-op password change."""
        if self.current_password.get_secret_value() == self.new_password.get_secret_value():
            raise ValueError("New password must differ from current password")
        return self

    model_config = ConfigDict(extra="forbid")

