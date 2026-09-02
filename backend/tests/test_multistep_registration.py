"""Tests for the three-step registration flow.

Step 1 registers with name/phone/password only, step 2 completes the
profile, step 3 stores location -- all through the existing endpoints.
"""

from fastapi.testclient import TestClient

from tests.helpers import DEFAULT_PASSWORD, registration_payload

MINIMAL_PASSWORD = DEFAULT_PASSWORD


def _minimal_registration(phone: str) -> dict[str, object]:
    """Return a step-1 payload: identity and credentials only."""
    return {
        "full_name": f"Multistep User {phone[-2:]}",
        "phone": phone,
        "password": MINIMAL_PASSWORD,
    }


def _register_minimal(client: TestClient, phone: str) -> dict[str, object]:
    response = client.post("/api/auth/register", json=_minimal_registration(phone))
    assert response.status_code == 201, response.text
    return response.json()


def _login(client: TestClient, phone: str) -> dict[str, str]:
    response = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": MINIMAL_PASSWORD},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


# ---------------------------------------------------------------------------
# Step 1 - minimal registration
# ---------------------------------------------------------------------------


def test_minimal_registration_succeeds_without_profile_fields(
    client: TestClient,
) -> None:
    body = _register_minimal(client, "9880000301")

    assert body["full_name"] == "Multistep User 01"
    assert body["annual_income"] is None
    assert body["category"] is None
    assert body["gender"] is None
    assert body["profile_complete"] is False


def test_login_works_immediately_after_minimal_registration(
    client: TestClient,
) -> None:
    _register_minimal(client, "9880000302")

    headers = _login(client, "9880000302")
    me = client.get("/api/auth/me", headers=headers)

    assert me.status_code == 200
    assert me.json()["profile_complete"] is False


# ---------------------------------------------------------------------------
# Step 2 and 3 - completing the profile through PUT /api/users/me
# ---------------------------------------------------------------------------


def test_profile_and_location_can_be_completed_in_two_updates(
    client: TestClient,
) -> None:
    _register_minimal(client, "9880000303")
    headers = _login(client, "9880000303")

    # Step 2: eligibility/profile screen fields.
    step_two = client.put(
        "/api/users/me",
        headers=headers,
        json={
            "annual_income": "325000.00",
            "category": "General",
            "gender": "Female",
            "state": "Madhya Pradesh",
            "district": "Bhopal",
        },
    )

    assert step_two.status_code == 200, step_two.text
    profile = step_two.json()
    assert profile["annual_income"] == "325000.00"
    assert profile["category"] == "GENERAL"  # casing still normalised
    assert profile["gender"] == "FEMALE"
    assert profile["state"] == "Madhya Pradesh"
    assert profile["district"] == "Bhopal"
    assert profile["profile_complete"] is True

    # Step 3: location screen fields.
    step_three = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": 23.2599, "longitude": 77.4126},
    )

    assert step_three.status_code == 200, step_three.text
    located = step_three.json()
    assert located["latitude"] == 23.2599
    assert located["longitude"] == 77.4126
    assert located["profile_complete"] is True


# ---------------------------------------------------------------------------
# Incomplete profiles must be refused clearly, never crash, never guessed
# ---------------------------------------------------------------------------


def test_incomplete_profile_match_returns_400_not_500(client: TestClient) -> None:
    _register_minimal(client, "9880000304")
    headers = _login(client, "9880000304")

    response = client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": "100000.00", "tenure_months": 60},
    )

    assert response.status_code == 400
    detail = response.json()["detail"]
    assert detail["message"] == "Profile is incomplete"
    assert set(detail["missing_fields"]) == {"annual_income", "category", "gender"}


def test_incomplete_profile_eligibility_returns_400_not_500(
    client: TestClient,
) -> None:
    _register_minimal(client, "9880000305")
    headers = _login(client, "9880000305")
    scheme_id = client.get("/api/schemes").json()["items"][0]["id"]

    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "100000.00"},
    )

    assert response.status_code == 400
    assert response.json()["detail"]["message"] == "Profile is incomplete"


def test_partially_completed_profile_reports_only_missing_fields(
    client: TestClient,
) -> None:
    _register_minimal(client, "9880000306")
    headers = _login(client, "9880000306")
    client.put("/api/users/me", headers=headers, json={"annual_income": "200000.00"})

    response = client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": "100000.00", "tenure_months": 60},
    )

    assert response.status_code == 400
    assert set(response.json()["detail"]["missing_fields"]) == {"category", "gender"}


def test_match_succeeds_once_profile_is_completed(client: TestClient) -> None:
    _register_minimal(client, "9880000307")
    headers = _login(client, "9880000307")
    client.put(
        "/api/users/me",
        headers=headers,
        json={
            "annual_income": "325000.00",
            "category": "GENERAL",
            "gender": "OTHER",
            "latitude": 23.2599,
            "longitude": 77.4126,
        },
    )

    response = client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": "100000.00", "tenure_months": 60},
    )

    assert response.status_code == 200
    assert response.json()["candidate_count"] > 0


# ---------------------------------------------------------------------------
# Validation strength and backward compatibility
# ---------------------------------------------------------------------------


def test_supplied_invalid_annual_income_is_still_rejected(
    client: TestClient,
) -> None:
    """Optional does not mean unvalidated: a supplied bad value still 422s."""
    payload = _minimal_registration("9880000308")
    payload["annual_income"] = -1

    response = client.post("/api/auth/register", json=payload)

    assert response.status_code == 422


def test_supplied_invalid_category_is_still_rejected(client: TestClient) -> None:
    payload = _minimal_registration("9880000309")
    payload["category"] = "NOT_A_CATEGORY"

    response = client.post("/api/auth/register", json=payload)

    assert response.status_code == 422


def test_complete_registration_payload_remains_backward_compatible(
    client: TestClient,
) -> None:
    """A pre-existing full registration payload still works unchanged."""
    response = client.post(
        "/api/auth/register",
        json=registration_payload("9880000310"),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["annual_income"] == "325000.00"
    assert body["category"] == "GENERAL"
    assert body["profile_complete"] is True


# ---------------------------------------------------------------------------
# Partner routing behaviour must be untouched by this change
# ---------------------------------------------------------------------------


def test_partner_routing_missing_location_behaviour_unchanged(
    client: TestClient,
) -> None:
    """Routing still reports missing location, independent of profile fields."""
    _register_minimal(client, "9880000311")
    headers = _login(client, "9880000311")

    response = client.get("/api/partners/routed", headers=headers)

    assert response.status_code == 400
    assert response.json()["detail"] == "User location is not configured"


def test_partner_routing_works_with_location_but_incomplete_profile(
    client: TestClient,
) -> None:
    """Routing depends only on coordinates, not on income/category/gender."""
    _register_minimal(client, "9880000312")
    headers = _login(client, "9880000312")
    client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": 23.2599, "longitude": 77.4126},
    )

    response = client.get("/api/partners/routed", headers=headers)

    assert response.status_code == 200
    assert response.json()
