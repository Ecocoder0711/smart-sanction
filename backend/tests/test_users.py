"""Authenticated current-user profile and ownership tests."""

import pytest
from fastapi.testclient import TestClient

from tests.helpers import register_and_login


def test_own_profile_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/users/me")

    assert response.status_code == 401


def test_authenticated_user_can_access_only_own_profile(client: TestClient) -> None:
    first_user, first_headers = register_and_login(client, "9880000011")
    second_user, _ = register_and_login(client, "9880000012")

    own_response = client.get("/api/users/me", headers=first_headers)
    directory_response = client.get("/api/users", headers=first_headers)
    other_response = client.get(
        f"/api/users/{second_user['id']}",
        headers=first_headers,
    )

    assert own_response.status_code == 200
    assert own_response.json()["id"] == first_user["id"]
    assert "password_hash" not in own_response.json()
    assert directory_response.status_code == 404
    assert other_response.status_code == 404


def test_update_own_profile_and_reject_duplicate_phone(client: TestClient) -> None:
    first_user, first_headers = register_and_login(client, "9880000013")
    second_user, _ = register_and_login(client, "9880000014")

    updated = client.put(
        "/api/users/me",
        headers=first_headers,
        json={
            "full_name": "Updated Authenticated User",
            "annual_income": "475000.00",
            "latitude": None,
            "longitude": None,
        },
    )
    duplicate = client.put(
        "/api/users/me",
        headers=first_headers,
        json={"phone": second_user["phone"]},
    )
    forbidden_field = client.put(
        "/api/users/me",
        headers=first_headers,
        json={"password_hash": "client-controlled"},
    )

    assert updated.status_code == 200
    assert updated.json()["id"] == first_user["id"]
    assert updated.json()["full_name"] == "Updated Authenticated User"
    assert float(updated.json()["annual_income"]) == 475000
    assert updated.json()["latitude"] is None
    assert duplicate.status_code == 409
    assert forbidden_field.status_code == 422


def test_profile_location_and_gender_are_persisted_and_serialized(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000015")

    updated = client.put(
        "/api/users/me",
        headers=headers,
        json={
            "state": "Madhya Pradesh",
            "district": "Bhopal",
            "gender": "Female",
        },
    )
    user_profile = client.get("/api/users/me", headers=headers)
    auth_profile = client.get("/api/auth/me", headers=headers)

    assert updated.status_code == 200, updated.text
    assert updated.json()["state"] == "Madhya Pradesh"
    assert updated.json()["district"] == "Bhopal"
    assert updated.json()["gender"] == "FEMALE"
    assert user_profile.status_code == 200
    assert user_profile.json()["state"] == "Madhya Pradesh"
    assert user_profile.json()["district"] == "Bhopal"
    assert user_profile.json()["gender"] == "FEMALE"
    assert auth_profile.status_code == 200
    assert auth_profile.json()["state"] == "Madhya Pradesh"
    assert auth_profile.json()["district"] == "Bhopal"
    assert auth_profile.json()["gender"] == "FEMALE"


@pytest.mark.parametrize(
    ("phone", "invalid_category"),
    [
        ("9880000016", "Women"),
        ("9880000017", "Minority"),
    ],
)
def test_profile_update_rejects_non_caste_categories(
    client: TestClient,
    phone: str,
    invalid_category: str,
) -> None:
    _, headers = register_and_login(client, phone)

    response = client.put(
        "/api/users/me",
        headers=headers,
        json={"category": invalid_category},
    )

    assert response.status_code == 422
