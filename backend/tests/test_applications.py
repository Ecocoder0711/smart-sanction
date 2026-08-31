"""Authenticated application creation and ownership tests."""

from fastapi.testclient import TestClient

from tests.helpers import register_and_login


def _valid_application_payload(client: TestClient) -> dict[str, object]:
    scheme_id = client.get("/api/schemes").json()["items"][0]["id"]
    partner_id = client.get("/api/partners").json()[0]["id"]
    return {
        "scheme_id": scheme_id,
        "partner_id": partner_id,
        "requested_amount": "125000.00",
    }


def test_application_endpoints_require_authentication(client: TestClient) -> None:
    payload = _valid_application_payload(client)

    assert client.get("/api/applications").status_code == 401
    assert client.get("/api/applications/1").status_code == 401
    assert client.post("/api/applications", json=payload).status_code == 401


def test_create_application_sets_owner_status_and_null_ml(client: TestClient) -> None:
    user, headers = register_and_login(client, "9880000021")
    response = client.post(
        "/api/applications",
        headers=headers,
        json=_valid_application_payload(client),
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["user_id"] == user["id"]
    assert payload["status"] == "submitted"
    assert payload["ml_match_score"] is None
    assert payload["ml_approval_probability"] is None


def test_authenticated_user_sees_only_owned_applications(client: TestClient) -> None:
    first_user, first_headers = register_and_login(client, "9880000022")
    second_user, second_headers = register_and_login(client, "9880000023")
    payload = _valid_application_payload(client)
    first_application = client.post(
        "/api/applications",
        headers=first_headers,
        json=payload,
    ).json()
    second_application = client.post(
        "/api/applications",
        headers=second_headers,
        json=payload,
    ).json()

    first_list = client.get("/api/applications", headers=first_headers)
    own_detail = client.get(
        f"/api/applications/{first_application['id']}",
        headers=first_headers,
    )
    other_detail = client.get(
        f"/api/applications/{second_application['id']}",
        headers=first_headers,
    )

    assert first_list.status_code == 200
    assert first_list.json()["total"] == 1
    assert all(
        item["user_id"] == first_user["id"]
        for item in first_list.json()["items"]
    )
    assert own_detail.status_code == 200
    assert other_detail.status_code == 404
    assert second_user["id"] != first_user["id"]


def test_client_cannot_override_application_owner(client: TestClient) -> None:
    user, headers = register_and_login(client, "9880000024")
    payload = _valid_application_payload(client)
    payload["user_id"] = user["id"] + 1

    response = client.post("/api/applications", headers=headers, json=payload)

    assert response.status_code == 422


def test_invalid_scheme_and_partner_return_404(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000025")
    payload = _valid_application_payload(client)
    invalid_scheme = dict(payload, scheme_id=999999)
    invalid_partner = dict(payload, partner_id=999999)

    scheme_response = client.post(
        "/api/applications",
        headers=headers,
        json=invalid_scheme,
    )
    partner_response = client.post(
        "/api/applications",
        headers=headers,
        json=invalid_partner,
    )

    assert scheme_response.status_code == 404
    assert scheme_response.json() == {"detail": "Scheme not found"}
    assert partner_response.status_code == 404
    assert partner_response.json() == {"detail": "Partner not found"}


def test_application_filters_and_missing_resource(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000026")
    payload = _valid_application_payload(client)
    created = client.post(
        "/api/applications",
        headers=headers,
        json=payload,
    ).json()

    filtered = client.get(
        "/api/applications",
        headers=headers,
        params={"status": "submitted", "scheme_id": created["scheme_id"]},
    )
    invalid_status = client.get(
        "/api/applications",
        headers=headers,
        params={"status": "invented"},
    )
    missing = client.get("/api/applications/999999", headers=headers)

    assert filtered.status_code == 200
    assert filtered.json()["total"] == 1
    assert invalid_status.status_code == 422
    assert missing.status_code == 404

