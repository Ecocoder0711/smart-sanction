"""Tests for the routed partners embedded in POST /api/match.

/api/match runs the same two-stage routing as /api/partners/routed, but bounds
Stage 1 by the configured recommendation radius. These tests pin that bound in
place: without it a user far from every branch would still be handed the K
nearest on Earth, because the health score's proximity term saturates beyond
PROXIMITY_REFERENCE_KM and cannot tell 60 km from 8,000 km.
"""

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.services.partner_routing_service import (
    DEFAULT_K,
    MATCH_PARTNER_K,
    PROXIMITY_REFERENCE_KM,
)
from app.utils.location import haversine_distance_km
from seed.partners import SYNTHETIC_PARTNERS
from tests.helpers import register_and_login

# tests.helpers registers users at this location (Bhopal), which the expanded
# deterministic seed surrounds with several clustered branches.
USER_LATITUDE = 23.2599
USER_LONGITUDE = 77.4126

# Nowhere near any seeded branch: the nearest is roughly 8,200 km away.
EMPTY_OCEAN_LATITUDE = 0.0
EMPTY_OCEAN_LONGITUDE = 0.0

pytestmark = pytest.mark.usefixtures("ml_disabled")


def _match(client: TestClient, headers: dict[str, str], *, amount: str = "100000.00"):
    return client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": amount, "tenure_months": 36},
    )


def _eligible_partner_distances(latitude: float, longitude: float) -> list[float]:
    """Independently recompute eligible partner distances from the seed."""
    return sorted(
        haversine_distance_km(
            latitude,
            longitude,
            float(partner["latitude"]),
            float(partner["longitude"]),
        )
        for partner in SYNTHETIC_PARTNERS
        if partner["is_active"] and float(partner["quota_remaining"]) > 0
    )


def _first_candidate_partners(client: TestClient, headers: dict[str, str]) -> list[dict]:
    body = _match(client, headers).json()
    assert body["candidate_count"] > 0
    return body["candidates"][0]["partners"]


def test_match_partners_carry_health_score_in_unit_range(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000501")

    body = _match(client, headers).json()

    assert body["candidate_count"] > 0
    for candidate in body["candidates"]:
        assert candidate["partners"], "expected routed partners near the seed user"
        for partner in candidate["partners"]:
            assert "health_score" in partner, (
                "health_score was dropped -- MatchCandidate.partners must be "
                "typed as RoutedPartnerResponse, not its parent"
            )
            assert 0.0 <= partner["health_score"] <= 1.0


def test_match_partners_are_ordered_by_health_score_descending(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000502")

    partners = _first_candidate_partners(client, headers)

    scores = [partner["health_score"] for partner in partners]
    assert scores == sorted(scores, reverse=True)
    # Ordering is health-first, so it is NOT generally distance-sorted; that is
    # the whole point of the change and the previous contract.
    assert len(scores) > 1


def test_match_partner_ordering_tie_breaks_deterministically(
    client: TestClient,
) -> None:
    """Full sort key is (-health_score, distance_km, id), applied consistently."""
    _, headers = register_and_login(client, "9880000503")

    partners = _first_candidate_partners(client, headers)

    keys = [
        (-partner["health_score"], partner["distance_km"], partner["id"])
        for partner in partners
    ]
    assert keys == sorted(keys)


def test_match_partner_routing_is_repeatable(client: TestClient) -> None:
    """Identical inputs must produce an identical list, order included."""
    _, headers = register_and_login(client, "9880000504")

    first = _first_candidate_partners(client, headers)
    second = _first_candidate_partners(client, headers)

    assert first == second


def test_match_returns_at_most_k_partners(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000505")
    radius = get_settings().recommended_partner_radius_km
    within_radius = [
        distance
        for distance in _eligible_partner_distances(USER_LATITUDE, USER_LONGITUDE)
        if distance <= radius
    ]
    # The cap must actually bite here, or the assertion proves nothing.
    assert len(within_radius) > MATCH_PARTNER_K

    body = _match(client, headers).json()

    for candidate in body["candidates"]:
        assert len(candidate["partners"]) <= MATCH_PARTNER_K
    assert len(body["candidates"][0]["partners"]) == MATCH_PARTNER_K


def test_match_never_returns_a_partner_beyond_the_configured_radius(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000506")
    radius = get_settings().recommended_partner_radius_km

    body = _match(client, headers).json()

    for candidate in body["candidates"]:
        for partner in candidate["partners"]:
            assert partner["distance_km"] <= radius


def test_user_far_from_every_partner_receives_none(client: TestClient) -> None:
    """The regression this whole change hinges on.

    Routing's default radius is effectively unbounded, so calling it without a
    radius here would return five branches ~8,200 km away, each with a
    plausible-looking health score.
    """
    _, headers = register_and_login(client, "9880000507")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": EMPTY_OCEAN_LATITUDE, "longitude": EMPTY_OCEAN_LONGITUDE},
    )
    assert update.status_code == 200

    nearest = _eligible_partner_distances(
        EMPTY_OCEAN_LATITUDE, EMPTY_OCEAN_LONGITUDE
    )[0]
    assert nearest > PROXIMITY_REFERENCE_KM, "seed no longer isolates this point"

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["candidate_count"] > 0, "eligibility must survive having no partner"
    assert all(not item["partners"] for item in body["candidates"])
    assert all(
        "No available partners were found" in item["partner_message"]
        for item in body["candidates"]
    )


def test_missing_user_coordinates_behaviour_is_unchanged(
    client: TestClient,
) -> None:
    _, headers = register_and_login(client, "9880000508")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": None, "longitude": None},
    )
    assert update.status_code == 200

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["candidate_count"] > 0
    assert all(not item["partners"] for item in body["candidates"])
    assert all(
        "User location is not configured" in item["partner_message"]
        for item in body["candidates"]
    )


def test_partner_message_describes_health_ranking(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000509")
    radius = get_settings().recommended_partner_radius_km

    body = _match(client, headers).json()

    message = body["candidates"][0]["partner_message"]
    assert f"within {radius:g} km" in message
    assert "health score" in message
    # The old wording promised distance ordering, which is no longer true.
    assert "ordered by distance" not in message


def test_same_routed_partners_are_attached_to_every_candidate(
    client: TestClient,
) -> None:
    """Routing depends only on the user, so it must not vary per scheme."""
    _, headers = register_and_login(client, "9880000510")

    body = _match(client, headers).json()

    assert body["candidate_count"] > 1, "need multiple candidates to compare"
    partner_lists = [
        [partner["id"] for partner in candidate["partners"]]
        for candidate in body["candidates"]
    ]
    assert len({tuple(ids) for ids in partner_lists}) == 1


def test_routed_endpoint_is_unaffected_by_the_matching_radius_bound(
    client: TestClient,
) -> None:
    """/api/partners/routed keeps its unbounded-radius contract.

    A user with no branch inside the recommendation radius still gets K
    partners here, while the same user gets none from /api/match.
    """
    _, headers = register_and_login(client, "9880000511")
    update = client.put(
        "/api/users/me",
        headers=headers,
        json={"latitude": EMPTY_OCEAN_LATITUDE, "longitude": EMPTY_OCEAN_LONGITUDE},
    )
    assert update.status_code == 200
    radius = get_settings().recommended_partner_radius_km

    routed = client.get("/api/partners/routed", headers=headers)
    matched = _match(client, headers)

    assert routed.status_code == 200
    routed_partners = routed.json()
    assert len(routed_partners) == DEFAULT_K
    assert all(item["distance_km"] > radius for item in routed_partners), (
        "expected the routed endpoint to reach far beyond the match radius"
    )

    assert matched.status_code == 200
    assert all(
        not candidate["partners"] for candidate in matched.json()["candidates"]
    )
