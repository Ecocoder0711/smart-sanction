"""SQLAlchemy engine and request-scoped session dependencies."""

from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session

from app.core.config import get_settings


class DatabaseNotConfiguredError(RuntimeError):
    """Raised when a database operation is attempted without DATABASE_URL."""


@lru_cache
def get_engine() -> Engine:
    """Create the process-wide connection pool lazily."""
    database_url = get_settings().database_url
    if not database_url:
        raise DatabaseNotConfiguredError(
            "DATABASE_URL is not configured. Copy .env.example to .env and set it."
        )

    return create_engine(database_url, pool_pre_ping=True)


def get_db() -> Generator[Session, None, None]:
    """Provide a fresh SQLAlchemy session for one FastAPI request."""
    with Session(get_engine()) as session:
        yield session

