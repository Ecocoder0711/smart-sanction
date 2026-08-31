"""Pure and scheme-backed financial calculator API tests."""

from fastapi.testclient import TestClient


def test_normal_reducing_balance_loan(client: TestClient) -> None:
    response = client.post(
        "/api/calculator",
        json={
            "principal": "100000.00",
            "annual_interest_rate": "12.0000",
            "tenure_months": 12,
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["emi"] == "8884.88"
    assert payload["total_repayment"] == "106618.55"
    assert payload["total_interest"] == "6618.55"


def test_zero_interest_loan(client: TestClient) -> None:
    response = client.post(
        "/api/calculator",
        json={
            "principal": "1200.00",
            "annual_interest_rate": "0",
            "tenure_months": 12,
        },
    )

    assert response.status_code == 200
    assert response.json()["emi"] == "100.00"
    assert response.json()["total_repayment"] == "1200.00"
    assert response.json()["total_interest"] == "0.00"


def test_calculator_rejects_invalid_values(client: TestClient) -> None:
    invalid_principal = client.post(
        "/api/calculator",
        json={"principal": 0, "annual_interest_rate": 5, "tenure_months": 12},
    )
    invalid_tenure = client.post(
        "/api/calculator",
        json={"principal": 1000, "annual_interest_rate": 5, "tenure_months": 0},
    )
    invalid_interest = client.post(
        "/api/calculator",
        json={"principal": 1000, "annual_interest_rate": -1, "tenure_months": 12},
    )

    assert invalid_principal.status_code == 422
    assert invalid_tenure.status_code == 422
    assert invalid_interest.status_code == 422


def test_monetary_outputs_have_two_decimal_places(client: TestClient) -> None:
    response = client.post(
        "/api/calculator",
        json={
            "principal": "1000.00",
            "annual_interest_rate": "7.2500",
            "tenure_months": 7,
        },
    )

    assert response.status_code == 200
    for field in ("principal", "emi", "total_repayment", "total_interest"):
        assert len(response.json()[field].split(".")[1]) == 2


def test_scheme_calculator_uses_stored_interest_rate(client: TestClient) -> None:
    scheme = client.get("/api/schemes").json()["items"][0]
    response = client.post(
        f"/api/schemes/{scheme['id']}/calculate",
        json={"requested_amount": "100000.00", "tenure_months": 24},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["scheme"]["id"] == scheme["id"]
    assert payload["interest_rate"] == scheme["interest_rate"]
    assert payload["principal"] == "100000.00"


def test_scheme_calculator_missing_and_inactive(client: TestClient) -> None:
    inactive_scheme = client.get(
        "/api/schemes",
        params={"is_active": "false"},
    ).json()["items"][0]
    missing = client.post(
        "/api/schemes/999999/calculate",
        json={"requested_amount": 100000, "tenure_months": 12},
    )
    inactive = client.post(
        f"/api/schemes/{inactive_scheme['id']}/calculate",
        json={"requested_amount": 100000, "tenure_months": 12},
    )

    assert missing.status_code == 404
    assert inactive.status_code == 400
    assert inactive.json() == {"detail": "Scheme is inactive"}

