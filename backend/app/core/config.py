"""Environment-based application configuration."""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Validated settings loaded from environment variables or backend/.env."""

    app_name: str = "SMART-SANCTION API"
    app_version: str = "0.1.0"
    environment: str = "development"
    debug: bool = False

    database_url: str | None = Field(default=None, validation_alias="DATABASE_URL")
    jwt_secret_key: str | None = Field(default=None, validation_alias="JWT_SECRET_KEY")
    jwt_algorithm: Literal["HS256", "HS384", "HS512"] = Field(
        default="HS256",
        validation_alias="JWT_ALGORITHM",
    )
    access_token_expire_minutes: int = Field(
        default=60,
        ge=1,
        validation_alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    recommended_partner_radius_km: float = Field(
        default=50.0,
        gt=0,
        le=20_000,
        validation_alias="RECOMMENDED_PARTNER_RADIUS_KM",
    )
    ml_available: bool = Field(default=False, validation_alias="ML_AVAILABLE")

    model_config = SettingsConfigDict(
        env_prefix="SMART_SANCTION_",
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Return one immutable-by-convention settings instance per process."""
    return Settings()
