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
from app.core.config import get_settings
from app.database.database import Base
from app.database.session import get_db
from app.main import app
from app.services.ml.random_forest_engine import get_ml_engine
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


def _set_ml_available(monkeypatch: pytest.MonkeyPatch, value: str) -> None:
    """Pin ML_AVAILABLE for one test regardless of the developer's shell.

    Settings are cached per process, so the cache is cleared on the way in and
    again on the way out; monkeypatch restores the original variable in
    between. Without this a suite run under `ML_AVAILABLE=true` would silently
    assert something different from the same run under the repository default.
    """
    monkeypatch.setenv("ML_AVAILABLE", value)
    get_settings.cache_clear()


@pytest.fixture
def ml_disabled(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Force ML off, matching the repository's default configuration."""
    _set_ml_available(monkeypatch, "false")
    yield
    get_settings.cache_clear()


@pytest.fixture
def ml_enabled(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Force ML on without depending on the ambient environment."""
    _set_ml_available(monkeypatch, "true")
    yield
    get_settings.cache_clear()


@pytest.fixture
def use_ml_engine() -> Generator[object, None, None]:
    """Install a specific MatchingEngine for one test, then remove only it.

    Overriding the dependency (rather than the on-disk file) keeps these tests
    independent of the gitignored random_forest_v1.joblib artifact, which is
    absent on a fresh clone.
    """

    def _install(engine: object) -> object:
        app.dependency_overrides[get_ml_engine] = lambda: engine
        return engine

    yield _install
    # Pop only this override: get_db belongs to the session-scoped client.
    app.dependency_overrides.pop(get_ml_engine, None)

