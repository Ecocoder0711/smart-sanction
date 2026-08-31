"""Isolated in-memory test database and FastAPI client fixtures."""

import os
from collections.abc import Generator

os.environ["JWT_SECRET_KEY"] = "phase5-test-only-secret-key-with-more-than-32-characters"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401 - register tables before creating the test schema
from app.database.database import Base
from app.database.session import get_db
from app.main import app
from seed.applications import seed_applications
from seed.partners import seed_partners
from seed.schemes import seed_categories, seed_schemes
from seed.users import seed_users


@pytest.fixture(scope="session")
def test_engine() -> Generator[Engine, None, None]:
    """Create a seeded SQLite database that is isolated from live PostgreSQL."""
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        categories, _ = seed_categories(session)
        schemes, _ = seed_schemes(session, categories)
        users, _ = seed_users(session)
        partners, _ = seed_partners(session)
        seed_applications(session, users, schemes, partners)
        session.commit()
    yield engine
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture(scope="session")
def client(test_engine: Engine) -> Generator[TestClient, None, None]:
    """Provide an API client whose database dependency uses only SQLite."""

    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine) as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def db_session(test_engine: Engine) -> Generator[Session, None, None]:
    """Expose the isolated database for security-state assertions."""
    with Session(test_engine) as session:
        yield session

