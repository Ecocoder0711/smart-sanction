"""Channel partner and nearby search API tests."""

from fastapi.testclient import TestClient

from tests.helpers import register_and_login


def test_list_partners_keeps_zero_quota_visible(client: TestClient) -> None:
    response = client.get("/api/partners")

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 16
    assert any(float(item["quota_remaining"]) == 0 for item in payload)
    assert all(item["is_active"] for item in payload)


def test_retrieve_partner(client: TestClient) -> None:
    partner = client.get("/api/partners").json()[0]
    response = client.get(f"/api/partners/{partner['id']}")

    assert response.status_code == 200
    assert response.json()["branch_code"] == partner["branch_code"]


def test_nearby_partner_distance_and_order(client: TestClient) -> None:
    response = client.get(
        "/api/partners/nearby",
        params={
            "latitude": 23.2599,
            "longitude": 77.4126,
            "radius_km": 5,
            "limit": 5,
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload
    assert payload[0]["branch_code"] == "DEMO-BHO-001"
    assert payload[0]["distance_km"] < 0.2
    assert [item["distance_km"] for item in payload] == sorted(
        item["distance_km"] for item in payload
    )


def test_nearby_excludes_zero_quota_and_inactive(client: TestClient) -> None:
    zero_quota_response = client.get(
        "/api/partners/nearby",
        params={"latitude": 19.0748, "longitude": 72.879, "radius_km": 2},
    )
    inactive_response = client.get(
        "/api/partners/nearby",
        params={"latitude": 34.1518, "longitude": 77.5763, "radius_km": 2},
    )

    assert zero_quota_response.status_code == 200
    assert zero_quota_response.json() == []
    assert inactive_response.status_code == 200
    assert inactive_response.json() == []


def test_nearby_rejects_invalid_parameters(client: TestClient) -> None:
    invalid_latitude = client.get(
        "/api/partners/nearby",
        params={"latitude": 91, "longitude": 77, "radius_km": 5},
    )
    invalid_radius = client.get(
        "/api/partners/nearby",
        params={"latitude": 23, "longitude": 77, "radius_km": 0},
    )

    assert invalid_latitude.status_code == 422
    assert invalid_radius.status_code == 422


def test_recommended_partners_use_authenticated_user_location(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000041")
    response = client.get(
        "/api/partners/recommended",
        headers=headers,
        params={"radius_km": 5, "latitude": 28.6139, "longitude": 77.209},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload
    assert payload[0]["branch_code"] == "DEMO-BHO-001"
    assert all(item["distance_km"] <= 5 for item in payload)
    assert [item["distance_km"] for item in payload] == sorted(
        item["distance_km"] for item in payload
    )


def test_recommendations_exclude_unavailable_partners(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000042")
    response = client.get(
        "/api/partners/recommended",
        headers=headers,
        params={"radius_km": 20000},
    )

    assert response.status_code == 200
    branch_codes = {item["branch_code"] for item in response.json()}
    assert "DEMO-MUM-003" not in branch_codes
    assert "DEMO-AHM-015" not in branch_codes
    assert "DEMO-LEH-006" not in branch_codes
    assert "DEMO-RAI-017" not in branch_codes


def test_recommendations_require_auth_and_stored_location(client: TestClient) -> None:
    unauthenticated = client.get("/api/partners/recommended")
    _, headers = register_and_login(client, "9880000043")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": None, "longitude": None},
    )
    assert update.status_code == 200
    missing_location = client.get("/api/partners/recommended", headers=headers)

    assert unauthenticated.status_code == 401
    assert missing_location.status_code == 400
    assert missing_location.json() == {"detail": "User location is not configured"}
