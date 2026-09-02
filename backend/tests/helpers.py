"""Small HTTP helpers for authenticated API tests."""

from typing import Any

from fastapi.testclient import TestClient

DEFAULT_PASSWORD = "CorrectHorse123!"


def registration_payload(
    phone: str,
    *,
    password: str = DEFAULT_PASSWORD,
) -> dict[str, Any]:
    """Return a valid synthetic registration request."""
    return {
        "full_name": f"Authenticated Test User {phone[-2:]}",
        "phone": phone,
        "annual_income": "325000.00",
        "category": "GENERAL",
        "latitude": 23.2599,
        "longitude": 77.4126,
        "password": password,
    }


def register_and_login(
    client: TestClient,
    phone: str,
    *,
    password: str = DEFAULT_PASSWORD,
) -> tuple[dict[str, Any], dict[str, str]]:
    """Register a unique test account and return its user and Bearer header."""
    registration = client.post(
        "/api/auth/register",
        json=registration_payload(phone, password=password),
    )
    assert registration.status_code == 201, registration.text
    login = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": password},
    )
    assert login.status_code == 200, login.text
    token = login.json()["access_token"]
    return registration.json(), {"Authorization": f"Bearer {token}"}
