"""Scheme and category API tests."""

from fastapi.testclient import TestClient


def test_list_categories_is_deterministic(client: TestClient) -> None:
    response = client.get("/api/schemes/categories")

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 6
    names = [item["category_name"] for item in payload]
    assert names == sorted(names)


def test_list_schemes_defaults_to_active(client: TestClient) -> None:
    response = client.get("/api/schemes")

    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] == 11
    assert all(item["is_active"] for item in payload["items"])
    assert all("category" in item for item in payload["items"])


def test_filter_schemes(client: TestClient) -> None:
    category_response = client.get("/api/schemes", params={"category": "sc"})
    amount_response = client.get(
        "/api/schemes",
        params={"requested_amount": "2000000"},
    )
    inactive_response = client.get(
        "/api/schemes",
        params={"is_active": "false"},
    )

    assert category_response.status_code == 200
    assert category_response.json()["total"] == 2
    assert all(
        item["category"]["category_name"] == "SC"
        for item in category_response.json()["items"]
    )
    assert amount_response.status_code == 200
    assert all(
        float(item["max_loan_limit"]) >= 2_000_000
        for item in amount_response.json()["items"]
    )
    assert inactive_response.json()["total"] == 1
    assert inactive_response.json()["items"][0]["is_active"] is False


def test_get_existing_scheme(client: TestClient) -> None:
    scheme_id = client.get("/api/schemes").json()["items"][0]["id"]
    response = client.get(f"/api/schemes/{scheme_id}")

    assert response.status_code == 200
    assert response.json()["id"] == scheme_id
    assert response.json()["category"]["category_name"]


def test_nonexistent_scheme_returns_404(client: TestClient) -> None:
    response = client.get("/api/schemes/999999")

    assert response.status_code == 404
    assert response.json() == {"detail": "Scheme not found"}

