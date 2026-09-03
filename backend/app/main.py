"""FastAPI application entry point."""

from fastapi import FastAPI

from app.api.routes.applications import router as applications_router
from app.api.routes.auth import router as auth_router
from app.api.routes.calculator import router as calculator_router
from app.api.routes.eligibility import router as eligibility_router
from app.api.routes.health import router as health_router
from app.api.routes.matching import router as matching_router
from app.api.routes.nearby_banks import router as nearby_banks_router
from app.api.routes.partners import router as partners_router
from app.api.routes.schemes import router as schemes_router
from app.api.routes.users import router as users_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "Backend API for SMART-SANCTION. Current milestone: read-only core database "
        "APIs over explicitly synthetic development data. JWT authentication and "
        "user ownership are enabled. Deterministic eligibility, financial calculation, "
        "partner recommendation, and matching orchestration are available; ML is "
        "optional and unavailable by default."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(eligibility_router)
app.include_router(calculator_router)
app.include_router(matching_router)
app.include_router(schemes_router)
app.include_router(partners_router)
app.include_router(nearby_banks_router)
app.include_router(users_router)
app.include_router(applications_router)
