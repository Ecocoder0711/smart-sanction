"""End-to-end tests for authenticated deterministic matching orchestration.

Every test here asserts the ML-*disabled* contract, so each one takes the
`ml_disabled` fixture rather than inheriting whatever ML_AVAILABLE happens to
be set to in the developer's shell. The ML-enabled contract lives in
test_matching_ml_enabled.py.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Application
from tests.helpers import register_and_login

# Applied to every test in this module: these assertions are only meaningful
# with ML off, and pinning it here keeps them true under `ML_AVAILABLE=true`.
pytestmark = pytest.mark.usefixtures("ml_disabled")


def _match(
    client: TestClient,
    headers: dict[str, str],
    *,
    amount: str = "100000.00",
    tenure: int = 36,
):
    return client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": amount, "tenure_months": tenure},
    )


def test_authenticated_matching_returns_complete_deterministic_candidates(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000061")

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["requested_amount"] == "100000.00"
    assert body["tenure_months"] == 36
    assert body["candidate_count"] == 3
    assert body["candidate_count"] == len(body["candidates"])
    assert body["ml_status"] == "unavailable"

    scheme_ids = [item["scheme"]["id"] for item in body["candidates"]]
    assert scheme_ids == sorted(scheme_ids)
    assert {
        item["scheme"]["category"]["category_name"] for item in body["candidates"]
    } == {"GENERAL", "ANY"}
    assert all(item["eligibility"]["eligible"] for item in body["candidates"])
    assert all(
        "Applicant category is eligible" in item["eligibility"]["reasons"]
        for item in body["candidates"]
    )
    assert all(item["financial"]["emi"] for item in body["candidates"])
    assert all(item["financial"]["tenure_months"] == 36 for item in body["candidates"])
    assert all(item["partners"] for item in body["candidates"])
    assert all(item["ml"] is None for item in body["candidates"])

    for candidate in body["candidates"]:
        partner_order = [
            (item["distance_km"], item["id"]) for item in candidate["partners"]
        ]
        assert partner_order == sorted(partner_order)


def test_matching_rejects_missing_auth_invalid_inputs_and_ownership_override(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000062")

    unauthenticated = client.post(
        "/api/match",
        json={"requested_amount": "100000.00"},
    )
    zero_amount = _match(client, headers, amount="0")
    invalid_tenure = _match(client, headers, tenure=0)
    ownership_override = client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": "100000.00", "user_id": 1},
    )

    assert unauthenticated.status_code == 401
    assert zero_amount.status_code == 422
    assert invalid_tenure.status_code == 422
    assert ownership_override.status_code == 422


def test_no_eligible_scheme_is_a_valid_empty_business_response(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000063")

    response = _match(client, headers, amount="4000000.00")

    assert response.status_code == 200
    body = response.json()
    assert body["candidate_count"] == 0
    assert body["candidates"] == []
    assert body["message"] == (
        "No matching scheme was found for the requested amount and profile."
    )
    assert body["ml_status"] == "unavailable"


def test_no_nearby_partners_preserves_eligible_candidates(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000064")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": 0, "longitude": 0},
    )
    assert update.status_code == 200

    response = _match(client, headers)

    assert response.status_code == 200
    assert response.json()["candidate_count"] > 0
    assert all(not item["partners"] for item in response.json()["candidates"])
    assert all(
        "No available partners were found" in item["partner_message"]
        for item in response.json()["candidates"]
    )


def test_missing_coordinates_preserves_eligible_candidates(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000065")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": None, "longitude": None},
    )
    assert update.status_code == 200

    response = _match(client, headers)

    assert response.status_code == 200
    assert response.json()["candidate_count"] > 0
    assert all(not item["partners"] for item in response.json()["candidates"])
    assert all(
        "User location is not configured" in item["partner_message"]
        for item in response.json()["candidates"]
    )


def test_matching_does_not_persist_or_populate_ml_fields(
    client: TestClient,
    db_session: Session,
) -> None:
    _, headers = register_and_login(client, "9880000066")
    before = db_session.scalar(select(func.count(Application.id)))

    response = _match(client, headers)

    db_session.expire_all()
    after = db_session.scalar(select(func.count(Application.id)))
    non_null_ml = db_session.scalar(
        select(func.count(Application.id)).where(
            (Application.ml_match_score.is_not(None))
            | (Application.ml_approval_probability.is_not(None))
        )
    )
    assert response.status_code == 200
    assert before == after
    assert non_null_ml == 0
    assert all(item["ml"] is None for item in response.json()["candidates"])
