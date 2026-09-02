"""Tests for two-stage geo-spatial partner routing and the health score."""

from fastapi.testclient import TestClient

from app.services.partner_routing_service import (
    DEFAULT_K,
    calculate_health_score,
)
from app.utils.location import haversine_distance_km
from seed.partners import SYNTHETIC_PARTNERS
from tests.helpers import register_and_login

# tests.helpers registers users at this location (Bhopal), which the expanded
# deterministic seed surrounds with several clustered branches.
USER_LATITUDE = 23.2599
USER_LONGITUDE = 77.4126


def _expected_nearest_branch_codes(k: int) -> list[str]:
    """Independently recompute the nearest eligible branches from the seed."""
    eligible = [
        (
            haversine_distance_km(
                USER_LATITUDE,
                USER_LONGITUDE,
                float(partner["latitude"]),
                float(partner["longitude"]),
            ),
            str(partner["branch_code"]),
        )
        for partner in SYNTHETIC_PARTNERS
        if partner["is_active"] and float(partner["quota_remaining"]) > 0
    ]
    eligible.sort()
    return [code for _, code in eligible[:k]]


# --------------------------------------------------------------------------
# Health score unit tests (pure arithmetic, no database)
# --------------------------------------------------------------------------


def test_higher_npa_lowers_health_score() -> None:
    healthier = calculate_health_score(
        npa_percentage=1.0, quota_remaining=1_000_000, distance_km=10
    )
    riskier = calculate_health_score(
        npa_percentage=12.0, quota_remaining=1_000_000, distance_km=10
    )
    assert healthier > riskier


def test_higher_quota_raises_health_score() -> None:
    smaller = calculate_health_score(
        npa_percentage=5.0, quota_remaining=500_000, distance_km=10
    )
    larger = calculate_health_score(
        npa_percentage=5.0, quota_remaining=5_000_000, distance_km=10
    )
    assert larger > smaller


def test_closer_distance_raises_health_score() -> None:
    near = calculate_health_score(
        npa_percentage=5.0, quota_remaining=1_000_000, distance_km=2
    )
    far = calculate_health_score(
        npa_percentage=5.0, quota_remaining=1_000_000, distance_km=40
    )
    assert near > far


def test_health_score_always_within_unit_range() -> None:
    extremes = [
        (0.0, 0.0, 0.0),
        (100.0, 0.0, 10_000.0),
        (0.0, 99_000_000.0, 0.0),
        (14.75, 6_000_000.0, 0.5),
        (-5.0, -100.0, -10.0),
    ]
    for npa, quota, distance in extremes:
        score = calculate_health_score(
            npa_percentage=npa, quota_remaining=quota, distance_km=distance
        )
        assert 0.0 <= score <= 1.0


def test_identical_inputs_produce_identical_scores() -> None:
    first = calculate_health_score(
        npa_percentage=6.5, quota_remaining=2_000_000, distance_km=7.5
    )
    second = calculate_health_score(
        npa_percentage=6.5, quota_remaining=2_000_000, distance_km=7.5
    )
    assert first == second


def test_beyond_proximity_reference_contributes_no_proximity_credit() -> None:
    """A partner past the proximity reference gets zero proximity credit only."""
    at_reference = calculate_health_score(
        npa_percentage=0.0, quota_remaining=0.0, distance_km=50.0
    )
    far_beyond = calculate_health_score(
        npa_percentage=0.0, quota_remaining=0.0, distance_km=5_000.0
    )
    assert at_reference == far_beyond == 0.40  # npa_health only


# --------------------------------------------------------------------------
# Routing endpoint tests
# --------------------------------------------------------------------------


def test_routed_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/partners/routed").status_code == 401


def test_routed_returns_geographically_nearest_k_candidates(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000201")

    response = client.get("/api/partners/routed", headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == DEFAULT_K
    # The returned set must be exactly the geographically nearest K, even
    # though they come back ordered by health score rather than distance.
    assert sorted(item["branch_code"] for item in payload) == sorted(
        _expected_nearest_branch_codes(DEFAULT_K)
    )


def test_healthier_but_farther_partner_cannot_enter_candidate_set(
    client: TestClient,
) -> None:
    """Stage 1 is geographic: health cannot pull in a partner outside nearest-K."""
    _, headers = register_and_login(client, "9880000202")

    response = client.get("/api/partners/routed", headers=headers, params={"k": 3})

    assert response.status_code == 200
    payload = response.json()
    returned = {item["branch_code"] for item in payload}
    assert returned == set(_expected_nearest_branch_codes(3))

    # Every excluded partner is strictly farther away, regardless of health.
    max_included_distance = max(item["distance_km"] for item in payload)
    excluded_healthier = [
        item
        for item in client.get(
            "/api/partners/routed", headers=headers, params={"k": 10}
        ).json()
        if item["branch_code"] not in returned
    ]
    assert excluded_healthier, "expected more than 3 eligible partners in the seed"
    assert all(
        item["distance_km"] >= max_included_distance for item in excluded_healthier
    )
    assert any(
        item["health_score"] > min(p["health_score"] for p in payload)
        for item in excluded_healthier
    ), "expected at least one farther-but-healthier partner to prove the ordering"


def test_routed_results_are_ordered_by_health_score_desc(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000203")

    payload = client.get(
        "/api/partners/routed", headers=headers, params={"k": 6}
    ).json()

    ordering = [
        (-item["health_score"], item["distance_km"], item["id"]) for item in payload
    ]
    assert ordering == sorted(ordering)
    assert all(0.0 <= item["health_score"] <= 1.0 for item in payload)


def test_routed_excludes_inactive_and_zero_quota_partners(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000204")

    payload = client.get(
        "/api/partners/routed", headers=headers, params={"k": 50}
    ).json()

    assert payload
    assert all(item["is_active"] for item in payload)
    assert all(float(item["quota_remaining"]) > 0 for item in payload)

    ineligible_codes = {
        str(partner["branch_code"])
        for partner in SYNTHETIC_PARTNERS
        if not partner["is_active"] or float(partner["quota_remaining"]) == 0
    }
    assert ineligible_codes, "seed should retain some ineligible partners"
    assert not ineligible_codes & {item["branch_code"] for item in payload}


def test_k_larger_than_available_partners_returns_all_eligible(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000205")

    payload = client.get(
        "/api/partners/routed", headers=headers, params={"k": 50}
    ).json()

    eligible_total = sum(
        1
        for partner in SYNTHETIC_PARTNERS
        if partner["is_active"] and float(partner["quota_remaining"]) > 0
    )
    assert len(payload) == min(50, eligible_total)


def test_routed_rejects_invalid_k(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000206")

    assert (
        client.get("/api/partners/routed", headers=headers, params={"k": 0}).status_code
        == 422
    )
    assert (
        client.get(
            "/api/partners/routed", headers=headers, params={"k": 999}
        ).status_code
        == 422
    )


def test_routed_requires_stored_user_coordinates(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000207")
    cleared = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": None, "longitude": None},
    )
    assert cleared.status_code == 200

    response = client.get("/api/partners/routed", headers=headers)

    assert response.status_code == 400
    assert response.json()["detail"] == "User location is not configured"


def test_no_eligible_partner_in_range_still_returns_cleanly(
    client: TestClient,
) -> None:
    """Routing has no radius cut, so a remote user still gets the nearest K."""
    _, headers = register_and_login(client, "9880000208")
    moved = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": 0, "longitude": 0},
    )
    assert moved.status_code == 200

    response = client.get("/api/partners/routed", headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == DEFAULT_K
    # Every partner is far away, so proximity contributes nothing to any score.
    assert all(item["distance_km"] > 50 for item in payload)


def test_existing_partner_endpoints_are_unchanged(client: TestClient) -> None:
    """The routed endpoint must not leak health_score into existing contracts."""
    _, headers = register_and_login(client, "9880000209")

    listing = client.get("/api/partners").json()
    nearby = client.get(
        "/api/partners/nearby",
        params={
            "latitude": USER_LATITUDE,
            "longitude": USER_LONGITUDE,
            "radius_km": 50,
        },
    ).json()
    recommended = client.get("/api/partners/recommended", headers=headers).json()

    assert all("health_score" not in item for item in listing)
    assert all("health_score" not in item for item in nearby)
    assert all("health_score" not in item for item in recommended)
    # Existing endpoints stay distance-ordered, not health-ordered.
    assert [item["distance_km"] for item in recommended] == sorted(
        item["distance_km"] for item in recommended
    )
