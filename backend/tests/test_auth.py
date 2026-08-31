"""Registration, login, JWT, current-user, and password tests."""

from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import create_access_token, verify_password
from app.models import User
from tests.helpers import DEFAULT_PASSWORD, register_and_login, registration_payload


def test_registration_hashes_password_and_hides_hash(
    client: TestClient,
    db_session: Session,
) -> None:
    phone = "9880000001"
    response = client.post("/api/auth/register", json=registration_payload(phone))

    assert response.status_code == 201
    payload = response.json()
    assert payload["phone"] == phone
    assert "password" not in payload
    assert "password_hash" not in payload
    user = db_session.scalar(select(User).where(User.phone == phone))
    assert user is not None
    assert user.password_hash != DEFAULT_PASSWORD
    assert verify_password(DEFAULT_PASSWORD, user.password_hash)


def test_duplicate_phone_returns_409(client: TestClient) -> None:
    phone = "9880000002"
    first = client.post("/api/auth/register", json=registration_payload(phone))
    second = client.post("/api/auth/register", json=registration_payload(phone))

    assert first.status_code == 201
    assert second.status_code == 409


def test_registration_rejects_invalid_input(client: TestClient) -> None:
    payload = registration_payload("9880000003")
    payload.update({"phone": "123", "annual_income": -1, "password": "short"})

    response = client.post("/api/auth/register", json=payload)

    assert response.status_code == 422


def test_login_success_and_generic_failures(client: TestClient) -> None:
    phone = "9880000004"
    client.post("/api/auth/register", json=registration_payload(phone))

    success = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": DEFAULT_PASSWORD},
    )
    incorrect = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": "IncorrectPassword1!"},
    )
    nonexistent = client.post(
        "/api/auth/login",
        json={"phone": "9880099999", "password": DEFAULT_PASSWORD},
    )
    malformed = client.post("/api/auth/login", json={"phone": phone})

    assert success.status_code == 200
    assert success.json()["token_type"] == "bearer"
    assert success.json()["access_token"]
    assert success.json()["user"]["phone"] == phone
    assert incorrect.status_code == nonexistent.status_code == 401
    assert incorrect.json() == nonexistent.json()
    assert malformed.status_code == 422


def test_current_user_and_token_failures(client: TestClient) -> None:
    user, headers = register_and_login(client, "9880000005")
    valid = client.get("/api/auth/me", headers=headers)
    missing = client.get("/api/auth/me")
    malformed = client.get(
        "/api/auth/me",
        headers={"Authorization": "Bearer not-a-jwt"},
    )
    expired_token = create_access_token(
        user["id"],
        expires_delta=timedelta(seconds=-1),
    )
    expired = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    nonexistent_token = create_access_token(999999)
    nonexistent = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {nonexistent_token}"},
    )

    assert valid.status_code == 200
    assert valid.json()["id"] == user["id"]
    assert missing.status_code == 401
    assert malformed.status_code == 401
    assert expired.status_code == 401
    assert nonexistent.status_code == 401


def test_password_change_and_new_login(client: TestClient) -> None:
    phone = "9880000006"
    _, headers = register_and_login(client, phone)
    incorrect = client.put(
        "/api/auth/password",
        headers=headers,
        json={
            "current_password": "IncorrectPassword1!",
            "new_password": "ReplacementPassword2!",
        },
    )
    changed = client.put(
        "/api/auth/password",
        headers=headers,
        json={
            "current_password": DEFAULT_PASSWORD,
            "new_password": "ReplacementPassword2!",
        },
    )
    old_login = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": DEFAULT_PASSWORD},
    )
    new_login = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": "ReplacementPassword2!"},
    )

    assert incorrect.status_code == 401
    assert changed.status_code == 204
    assert old_login.status_code == 401
    assert new_login.status_code == 200

