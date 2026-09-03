"""Environment-based application configuration."""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Validated settings loaded from environment variables or backend/.env.

    Note on naming: `env_prefix` below applies only to fields that do NOT
    declare a `validation_alias`. Every aliased field here (DATABASE_URL,
    JWT_*, ACCESS_TOKEN_EXPIRE_MINUTES, RECOMMENDED_PARTNER_RADIUS_KM,
    ML_AVAILABLE, OVERPASS_*, NEARBY_BANK_MAX_RADIUS_KM) is read by that bare
    alias, so `SMART_SANCTION_ML_AVAILABLE` is silently ignored and
    `ML_AVAILABLE` is the variable that works. Only `environment` and `debug`
    take the prefix.
    """

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

    # Real bank discovery via OpenStreetMap's Overpass API. Read-only, no key.
    # The public endpoint allows only two concurrent slots per source IP, which
    # is why discovery is mediated here and cached rather than called from each
    # device directly.
    overpass_primary_url: str = Field(
        default="https://overpass-api.de/api/interpreter",
        validation_alias="OVERPASS_PRIMARY_URL",
    )
    # The fallback must have worldwide coverage. Several public Overpass
    # instances are regional -- overpass.osm.ch answers 200 with zero elements
    # for an Indian query -- which would look like "no banks nearby" instead
    # of an outage. kumi and maps.mail.ru were both verified to return real
    # Indian results.
    overpass_fallback_url: str = Field(
        default="https://overpass.kumi.systems/api/interpreter",
        validation_alias="OVERPASS_FALLBACK_URL",
    )
    # Per-endpoint, not total. Sized against live 40 km queries, which are far
    # heavier than the 5 km ones this started with: Dehradun answers in ~7 s
    # (11 KB), but Delhi took 14.9 s (339 KB, 1,107 elements) and Bengaluru
    # 11.1 s (577 KB). A 12 s budget failed Delhi outright. Discovery loads
    # independently of the partner list, so a slow answer delays one section
    # rather than the screen.
    overpass_timeout_seconds: float = Field(
        default=25.0,
        gt=0,
        le=60,
        validation_alias="OVERPASS_TIMEOUT_SECONDS",
    )
    overpass_cache_ttl_seconds: float = Field(
        default=900.0,
        ge=0,
        validation_alias="OVERPASS_CACHE_TTL_SECONDS",
    )
    # Ceiling for real-bank discovery. Independent of
    # recommended_partner_radius_km, which bounds channel-partner routing and
    # is unchanged: the two systems answer different questions and one must
    # never be tuned by adjusting the other.
    nearby_bank_max_radius_km: float = Field(
        default=50.0,
        gt=0,
        le=100,
        validation_alias="NEARBY_BANK_MAX_RADIUS_KM",
    )

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
