"""Deterministic authenticated eligibility API tests."""

from fastapi.testclient import TestClient

from tests.helpers import register_and_login


def _scheme_id_by_name(
    client: TestClient,
    name: str,
    *,
    is_active: bool = True,
) -> int:
    response = client.get(
        "/api/schemes",
        params={"is_active": str(is_active).lower()},
    )
    return next(
        item["id"]
        for item in response.json()["items"]
        if item["scheme_name"] == name
    )


def test_eligible_applicant(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000031")
    scheme_id = _scheme_id_by_name(client, "Demo Universal Microenterprise Loan")

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "100000.00"},
    )

    assert response.status_code == 200
    assert response.json()["eligible"] is True
    assert "Applicant category is eligible" in response.json()["reasons"]


def test_category_mismatch_is_explained(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000032")
    scheme_id = _scheme_id_by_name(client, "Demo Community Growth Credit")

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "100000.00"},
    )

    assert response.status_code == 200
    assert response.json()["eligible"] is False
    assert (
        "Applicant category does not match the scheme category"
        in response.json()["reasons"]
    )


def test_income_exceeds_limit_is_explained(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000033")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"annual_income": "600000.00"},
    )
    assert update.status_code == 200
    scheme_id = _scheme_id_by_name(client, "Demo Universal Microenterprise Loan")

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "100000.00"},
    )

    assert response.status_code == 200
    assert response.json()["eligible"] is False
    assert "Annual income exceeds the scheme income limit" in response.json()["reasons"]


def test_requested_amount_exceeds_limit_is_explained(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000034")
    scheme_id = _scheme_id_by_name(client, "Demo Universal Microenterprise Loan")

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "400000.00"},
    )

    assert response.status_code == 200
    assert response.json()["eligible"] is False
    assert (
        "Requested amount exceeds the scheme maximum loan limit"
        in response.json()["reasons"]
    )


def test_inactive_scheme_is_an_ineligible_result(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000035")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"category": "Minority"},
    )
    assert update.status_code == 200
    scheme_id = _scheme_id_by_name(
        client,
        "Demo Minority Enterprise Accelerator",
        is_active=False,
    )

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "100000.00"},
    )

    assert response.status_code == 200
    assert response.json()["eligible"] is False
    assert "Scheme is inactive" in response.json()["reasons"]


def test_nonexistent_scheme_returns_404(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000036")

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": 999999, "requested_amount": "100000.00"},
    )

    assert response.status_code == 404


def test_invalid_amount_and_missing_auth_are_rejected(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000037")
    scheme_id = _scheme_id_by_name(client, "Demo Universal Microenterprise Loan")
    payload = {"scheme_id": scheme_id, "requested_amount": 0}

    invalid = client.post("/api/eligibility/check", headers=headers, json=payload)
    unauthenticated = client.post(
        "/api/eligibility/check",
        json={"scheme_id": scheme_id, "requested_amount": 100000},
    )

    assert invalid.status_code == 422
    assert unauthenticated.status_code == 401

