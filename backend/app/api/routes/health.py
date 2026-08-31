"""Application health endpoints."""

from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.database.session import get_engine

router = APIRouter(tags=["Health"])


class DatabaseHealth(BaseModel):
    """Database configuration and connectivity state."""

    configured: bool
    status: Literal["healthy", "not_configured", "unavailable"]


class HealthResponse(BaseModel):
    """Public service health response."""

    status: Literal["healthy", "degraded"]
    service: str
    database: DatabaseHealth


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Check backend health",
    description=(
        "Checks whether the API is running and, when DATABASE_URL is configured, "
        "whether PostgreSQL accepts a simple query."
    ),
    responses={
        200: {"description": "The API is running; database state is included."},
    },
)
def health_check() -> HealthResponse:
    """Return API and PostgreSQL connectivity status."""
    settings = get_settings()
    if not settings.database_url:
        return HealthResponse(
            status="degraded",
            service=settings.app_name,
            database=DatabaseHealth(configured=False, status="not_configured"),
        )

    try:
        with get_engine().connect() as connection:
            connection.execute(text("SELECT 1"))
    except (SQLAlchemyError, OSError):
        return HealthResponse(
            status="degraded",
            service=settings.app_name,
            database=DatabaseHealth(configured=True, status="unavailable"),
        )

    return HealthResponse(
        status="healthy",
        service=settings.app_name,
        database=DatabaseHealth(configured=True, status="healthy"),
    )

