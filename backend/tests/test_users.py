"""Authenticated current-user profile and ownership tests."""

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

