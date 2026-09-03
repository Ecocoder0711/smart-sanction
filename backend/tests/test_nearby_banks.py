"""Tests for real bank discovery from OpenStreetMap.

Every test here mocks the HTTP layer. Nothing in this file may reach the live
Overpass API: it is a shared public service with a two-slot-per-IP limit, and
a test suite that depends on it would be both rude and flaky.
"""

from __future__ import annotations

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.services import nearby_bank_service

# Connaught Place, Delhi -- a public landmark coordinate, used only as a
# fixed origin for distance assertions.
ORIGIN = (28.6304, 77.2177)


def _node(
    osm_id: int,
    name: str | None,
    latitude: float,
    longitude: float,
    **tags: str,
) -> dict[str, object]:
    element: dict[str, object] = {
        "type": "node",
        "id": osm_id,
        "lat": latitude,
        "lon": longitude,
    }
    element["tags"] = {**({"name": name} if name is not None else {}), **tags}
    return element


def _body(*elements: dict[str, object]) -> dict[str, object]:
    return {"elements": list(elements)}


@pytest.fixture(autouse=True)
def _isolate_cache() -> None:
    """Discovery caches in-process, so each test starts from empty."""
    nearby_bank_service.clear_cache()


@pytest.fixture
def transport(monkeypatch: pytest.MonkeyPatch):
    """Install a fake Overpass, recording every endpoint that was called."""

    calls: list[str] = []
    headers: list[dict[str, str]] = []

    def _install(handler) -> list[str]:
        class _FakeClient:
            def __init__(self, *args: object, **kwargs: object) -> None:
                headers.append(kwargs.get("headers") or {})

            def __enter__(self) -> "_FakeClient":
                return self

            def __exit__(self, *args: object) -> None:
                return None

            def post(self, url: str, data: dict[str, str]) -> httpx.Response:
                calls.append(url)
                request = httpx.Request("POST", url)
                result = handler(url, data)
                if isinstance(result, Exception):
                    raise result
                status_code, payload = result
                return httpx.Response(status_code, json=payload, request=request)

        monkeypatch.setattr(nearby_bank_service.httpx, "Client", _FakeClient)
        return calls

    _install.headers = headers  # type: ignore[attr-defined]
    return _install


class TestParsing:
    def test_named_banks_are_returned_nearest_first(self, transport) -> None:
        transport(
            lambda url, data: (
                200,
                _body(
                    _node(2, "State Bank of India", 28.6400, 77.2300),
                    _node(1, "ICICI Bank", 28.6310, 77.2180),
                ),
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert [bank.name for bank in result.items] == [
            "ICICI Bank",
            "State Bank of India",
        ]
        assert result.total == 2
        assert result.items[0].osm_id == "node/1"
        assert result.items[0].distance_km < result.items[1].distance_km

    def test_unnamed_elements_are_filtered_out(self, transport) -> None:
        """An unnamed pin tells the applicant nothing, so it is not shown."""
        transport(
            lambda url, data: (
                200,
                _body(
                    _node(1, "Canara Bank", 28.6310, 77.2180),
                    _node(2, None, 28.6311, 77.2181),
                    _node(3, "   ", 28.6312, 77.2182),
                ),
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert [bank.name for bank in result.items] == ["Canara Bank"]

    def test_distance_matches_the_partner_router_formula(self, transport) -> None:
        """Discovery and routing must not disagree about how far away a
        point is, so both use the same Haversine helper."""
        from app.utils.location import haversine_distance_km

        transport(
            lambda url, data: (200, _body(_node(1, "PNB", 28.7041, 77.1025)))
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=25,
        )

        expected = haversine_distance_km(ORIGIN[0], ORIGIN[1], 28.7041, 77.1025)
        assert result.items[0].distance_km == pytest.approx(expected, abs=0.001)

    def test_address_is_built_only_from_real_tags(self, transport) -> None:
        transport(
            lambda url, data: (
                200,
                _body(
                    _node(
                        1,
                        "Nainital Bank",
                        28.6310,
                        77.2180,
                        **{
                            "addr:housenumber": "12",
                            "addr:street": "Rajpur Road",
                            "addr:city": "Dehradun",
                        },
                    ),
                    _node(2, "SBI", 28.6311, 77.2181),
                ),
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )
        by_name = {bank.name: bank for bank in result.items}

        assert by_name["Nainital Bank"].address == "12, Rajpur Road, Dehradun"
        # No address tags at all: null, never a guess from the coordinates.
        assert by_name["SBI"].address is None

    def test_a_way_is_read_from_its_center(self, transport) -> None:
        """Banks mapped as building outlines have no lat/lon of their own."""
        transport(
            lambda url, data: (
                200,
                {
                    "elements": [
                        {
                            "type": "way",
                            "id": 77,
                            "center": {"lat": 28.6310, "lon": 77.2180},
                            "tags": {"name": "HDFC Bank"},
                        }
                    ]
                },
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert result.items[0].osm_id == "way/77"
        assert result.items[0].name == "HDFC Bank"

    def test_elements_without_coordinates_are_skipped(self, transport) -> None:
        transport(
            lambda url, data: (
                200,
                {
                    "elements": [
                        {"type": "way", "id": 5, "tags": {"name": "No Geometry"}},
                        _node(6, "Real Bank", 28.6310, 77.2180),
                    ]
                },
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert [bank.name for bank in result.items] == ["Real Bank"]

    def test_empty_response_is_not_an_error(self, transport) -> None:
        """A genuinely bankless area is an empty list, not a failure."""
        transport(lambda url, data: (200, {"elements": []}))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert result.items == []
        assert result.total == 0

    def test_results_beyond_the_radius_are_dropped(self, transport) -> None:
        """The cache key is rounded, so the caller's real distance decides."""
        transport(
            lambda url, data: (
                200,
                _body(
                    _node(1, "Near Bank", 28.6310, 77.2180),
                    _node(2, "Far Bank", 29.5000, 77.2180),
                ),
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert [bank.name for bank in result.items] == ["Near Bank"]


class TestReliability:
    def test_a_descriptive_user_agent_is_sent(self, transport) -> None:
        """Not politeness: without a User-Agent the public Overpass endpoint
        rejects the request with a non-JSON body or hangs until it times out.
        httpx sends none by default, so this header is load-bearing."""
        transport(lambda url, data: (200, {"elements": []}))

        nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        sent = transport.headers[0]
        assert "smart-sanction" in sent.get("User-Agent", "")

    def test_timeout_falls_back_to_the_mirror(self, transport) -> None:
        def handler(url: str, data: dict[str, str]):
            if url == get_settings().overpass_primary_url:
                return httpx.ReadTimeout("timed out")
            return (200, _body(_node(1, "Mirror Bank", 28.6310, 77.2180)))

        calls = transport(handler)

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert [bank.name for bank in result.items] == ["Mirror Bank"]
        assert calls == [
            get_settings().overpass_primary_url,
            get_settings().overpass_fallback_url,
        ]

    def test_rate_limited_primary_falls_back(self, transport) -> None:
        """429 is the failure this design exists to survive."""

        def handler(url: str, data: dict[str, str]):
            if url == get_settings().overpass_primary_url:
                return (429, {"detail": "slot limit"})
            return (200, _body(_node(1, "Mirror Bank", 28.6310, 77.2180)))

        calls = transport(handler)

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert result.total == 1
        assert len(calls) == 2

    def test_both_endpoints_failing_raises(self, transport) -> None:
        transport(lambda url, data: httpx.ConnectError("no network"))

        with pytest.raises(nearby_bank_service.NearbyBankUnavailableError):
            nearby_bank_service.find_nearby_banks(
                latitude=ORIGIN[0],
                longitude=ORIGIN[1],
                radius_km=5,
            )

    def test_malformed_json_is_treated_as_a_failure(self, transport) -> None:
        transport(lambda url, data: (200, "not a mapping"))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        # A body we cannot read yields nothing rather than crashing the screen.
        assert result.items == []

    def test_a_second_nearby_request_is_served_from_cache(self, transport) -> None:
        calls = transport(
            lambda url, data: (200, _body(_node(1, "Cached Bank", 28.6310, 77.2180)))
        )

        first = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )
        # A few metres away: the same rounded cache key, so no second call.
        second = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0] + 0.0002,
            longitude=ORIGIN[1] + 0.0002,
            radius_km=5,
        )

        assert len(calls) == 1
        assert first.cached is False
        assert second.cached is True
        assert second.total == first.total

    def test_cached_results_still_measure_from_the_real_coordinates(
        self,
        transport,
    ) -> None:
        """Rounding the cache key must not round the reported distance."""
        transport(
            lambda url, data: (200, _body(_node(1, "Bank", 28.6310, 77.2180)))
        )

        first = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )
        second = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0] + 0.002,
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert second.cached is True
        assert second.items[0].distance_km != first.items[0].distance_km

    def test_cache_can_be_disabled(
        self,
        transport,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setenv("OVERPASS_CACHE_TTL_SECONDS", "0")
        get_settings.cache_clear()
        calls = transport(
            lambda url, data: (200, _body(_node(1, "Bank", 28.6310, 77.2180)))
        )

        for _ in range(2):
            nearby_bank_service.find_nearby_banks(
                latitude=ORIGIN[0],
                longitude=ORIGIN[1],
                radius_km=5,
            )

        assert len(calls) == 2
        get_settings.cache_clear()

    def test_nothing_is_written_to_the_database(self, transport) -> None:
        """Discovery takes no session: OSM data never reaches PostgreSQL."""
        import inspect

        signature = inspect.signature(nearby_bank_service.find_nearby_banks)

        assert "session" not in signature.parameters
        assert "Session" not in nearby_bank_service.__doc__


class TestRadiusAndCap:
    """A 40 km radius is dense in a metro: live queries returned 1,041 named
    branches for Delhi and 1,493 for Bengaluru. The list is bounded, but only
    after distance decides which branches survive."""

    def _spread(self, count: int) -> dict[str, object]:
        """Banks at increasing distance, listed farthest-first on purpose.

        If the cap were applied before sorting, this ordering would keep the
        farthest branches and drop the nearest -- exactly the bug to prevent.
        """
        return _body(
            *[
                _node(index, f"Bank {index}", ORIGIN[0] + 0.002 * index, ORIGIN[1])
                for index in range(count, 0, -1)
            ]
        )

    def test_forty_km_radius_is_accepted(
        self,
        client: TestClient,
        transport,
    ) -> None:
        transport(lambda url, data: (200, self._spread(3)))

        response = client.get(
            "/api/nearby-banks",
            params={
                "latitude": ORIGIN[0],
                "longitude": ORIGIN[1],
                "radius_km": 40,
            },
        )

        assert response.status_code == 200, response.text
        assert response.json()["total"] == 3

    @pytest.mark.parametrize("radius", [0.5, 5, 40, 50])
    def test_radii_up_to_the_cap_are_accepted(
        self,
        client: TestClient,
        transport,
        radius: float,
    ) -> None:
        transport(lambda url, data: (200, {"elements": []}))

        response = client.get(
            "/api/nearby-banks",
            params={
                "latitude": ORIGIN[0],
                "longitude": ORIGIN[1],
                "radius_km": radius,
            },
        )

        assert response.status_code == 200, f"{radius} km should be allowed"

    @pytest.mark.parametrize("radius", [50.1, 60, 100])
    def test_radius_above_fifty_is_rejected(
        self,
        client: TestClient,
        radius: float,
    ) -> None:
        response = client.get(
            "/api/nearby-banks",
            params={
                "latitude": ORIGIN[0],
                "longitude": ORIGIN[1],
                "radius_km": radius,
            },
        )

        assert response.status_code == 422, f"{radius} km should be refused"

    def test_maximum_radius_is_fifty(self) -> None:
        assert get_settings().nearby_bank_max_radius_km == 50.0

    def test_results_are_capped_at_the_named_constant(self, transport) -> None:
        transport(lambda url, data: (200, self._spread(120)))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert nearby_bank_service.MAX_NEARBY_BANK_RESULTS == 50
        assert len(result.items) == 50
        assert result.total == 50
        # The count found is reported separately from the count shown.
        assert result.discovered == 120
        assert result.capped is True

    def test_the_cap_keeps_the_nearest_not_the_first_seen(
        self,
        transport,
    ) -> None:
        """The upstream lists these farthest-first; distance must still win."""
        transport(lambda url, data: (200, self._spread(120)))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert result.items[0].name == "Bank 1"
        assert result.items[-1].name == "Bank 50"
        distances = [bank.distance_km for bank in result.items]
        assert distances == sorted(distances)

    def test_an_uncapped_result_reports_itself_uncapped(
        self,
        transport,
    ) -> None:
        transport(lambda url, data: (200, self._spread(10)))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert result.capped is False
        assert result.discovered == result.total == 10

    def test_capping_is_deterministic(self, transport) -> None:
        """Same query, same rows -- ties broken by osm_id, not by chance."""
        transport(lambda url, data: (200, self._spread(120)))

        first = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )
        nearby_bank_service.clear_cache()
        second = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert [b.osm_id for b in first.items] == [b.osm_id for b in second.items]

    def test_identical_distances_break_ties_by_osm_id(self, transport) -> None:
        transport(
            lambda url, data: (
                200,
                _body(
                    _node(9, "Same Spot B", 28.6310, 77.2180),
                    _node(3, "Same Spot A", 28.6310, 77.2180),
                ),
            )
        )

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert [b.osm_id for b in result.items] == ["node/3", "node/9"]

    def test_every_returned_bank_is_inside_the_requested_radius(
        self,
        transport,
    ) -> None:
        """Includes branches Overpass returned that fall outside 40 km."""
        transport(lambda url, data: (200, self._spread(120)))

        result = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert all(bank.distance_km <= 40 for bank in result.items)

    def test_a_narrower_radius_excludes_farther_banks(self, transport) -> None:
        transport(lambda url, data: (200, self._spread(120)))

        wide = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )
        nearby_bank_service.clear_cache()
        narrow = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )

        assert narrow.discovered < wide.discovered
        assert all(bank.distance_km <= 5 for bank in narrow.items)

    def test_the_cache_still_works_at_forty_km(self, transport) -> None:
        calls = transport(lambda url, data: (200, self._spread(120)))

        first = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )
        second = nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0] + 0.0002,
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert len(calls) == 1
        assert second.cached is True
        assert second.capped is first.capped
        assert len(second.items) == 50

    def test_radius_is_part_of_the_cache_key(self, transport) -> None:
        """A 5 km answer must never be served for a 40 km question."""
        calls = transport(lambda url, data: (200, self._spread(120)))

        nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=5,
        )
        nearby_bank_service.find_nearby_banks(
            latitude=ORIGIN[0],
            longitude=ORIGIN[1],
            radius_km=40,
        )

        assert len(calls) == 2


class TestPartnerRoutingIsUnaffected:
    """Discovery and channel-partner routing are separate systems. Widening
    one must not move the other."""

    def test_partner_radius_is_still_fifty(self) -> None:
        assert get_settings().recommended_partner_radius_km == 50.0

    def test_partner_and_discovery_radii_are_independent_settings(self) -> None:
        # Distinct aliases, so tuning one cannot silently tune the other.
        fields = type(get_settings()).model_fields
        assert (
            fields["recommended_partner_radius_km"].validation_alias
            == "RECOMMENDED_PARTNER_RADIUS_KM"
        )
        assert (
            fields["nearby_bank_max_radius_km"].validation_alias
            == "NEARBY_BANK_MAX_RADIUS_KM"
        )

    def test_health_score_weights_are_untouched(self) -> None:
        from app.services import partner_routing_service as routing

        assert routing.NPA_WEIGHT == 0.40
        assert routing.CAPACITY_WEIGHT == 0.30
        assert routing.PROXIMITY_WEIGHT == 0.30
        assert routing.PROXIMITY_REFERENCE_KM == 50.0
        assert routing.MATCH_PARTNER_K == 5

    def test_routed_partners_still_answer(
        self,
        client: TestClient,
        transport,
    ) -> None:
        from tests.helpers import register_and_login

        transport(lambda url, data: (200, {"elements": []}))
        _, headers = register_and_login(client, "9880000802")

        routed = client.get("/api/partners/routed", headers=headers)

        assert routed.status_code == 200
        assert routed.json()
        assert "health_score" in routed.json()[0]


class TestEndpoint:
    def test_returns_discovered_banks(self, client: TestClient, transport) -> None:
        transport(
            lambda url, data: (200, _body(_node(1, "ICICI Bank", 28.6310, 77.2180)))
        )

        response = client.get(
            "/api/nearby-banks",
            params={"latitude": ORIGIN[0], "longitude": ORIGIN[1], "radius_km": 5},
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["total"] == 1
        assert body["items"][0]["name"] == "ICICI Bank"
        assert body["source"] == "openstreetmap"

    def test_discovered_banks_carry_no_partner_fields(
        self,
        client: TestClient,
        transport,
    ) -> None:
        """The separation is structural: these fields do not exist here."""
        transport(
            lambda url, data: (200, _body(_node(1, "ICICI Bank", 28.6310, 77.2180)))
        )

        response = client.get(
            "/api/nearby-banks",
            params={"latitude": ORIGIN[0], "longitude": ORIGIN[1]},
        )

        bank = response.json()["items"][0]
        for forbidden in (
            "health_score",
            "quota_remaining",
            "npa_percentage",
            "branch_code",
            "id",
        ):
            assert forbidden not in bank

    def test_outage_is_a_503(self, client: TestClient, transport) -> None:
        transport(lambda url, data: httpx.ConnectError("no network"))

        response = client.get(
            "/api/nearby-banks",
            params={"latitude": ORIGIN[0], "longitude": ORIGIN[1]},
        )

        assert response.status_code == 503

    def test_partner_routing_survives_a_discovery_outage(
        self,
        client: TestClient,
        transport,
    ) -> None:
        """The whole point of keeping the two systems apart."""
        from tests.helpers import register_and_login

        transport(lambda url, data: httpx.ConnectError("no network"))
        _, headers = register_and_login(client, "9880000801")

        discovery = client.get(
            "/api/nearby-banks",
            params={"latitude": ORIGIN[0], "longitude": ORIGIN[1]},
        )
        routed = client.get("/api/partners/routed", headers=headers)

        assert discovery.status_code == 503
        assert routed.status_code == 200
        assert routed.json()

    @pytest.mark.parametrize(
        ("params", "reason"),
        [
            ({"latitude": 91, "longitude": 77.2}, "latitude above range"),
            ({"latitude": -91, "longitude": 77.2}, "latitude below range"),
            ({"latitude": 28.6, "longitude": 181}, "longitude above range"),
            ({"latitude": 28.6, "longitude": 77.2, "radius_km": 0}, "zero radius"),
            ({"latitude": 28.6, "longitude": 77.2, "radius_km": -3}, "negative"),
            ({"longitude": 77.2}, "missing latitude"),
            ({"latitude": 28.6}, "missing longitude"),
        ],
    )
    def test_invalid_coordinates_are_rejected(
        self,
        client: TestClient,
        params: dict[str, float],
        reason: str,
    ) -> None:
        response = client.get("/api/nearby-banks", params=params)

        assert response.status_code == 422, reason

    def test_radius_above_the_cap_is_rejected(self, client: TestClient) -> None:
        response = client.get(
            "/api/nearby-banks",
            params={
                "latitude": ORIGIN[0],
                "longitude": ORIGIN[1],
                "radius_km": get_settings().nearby_bank_max_radius_km + 1,
            },
        )

        assert response.status_code == 422

    def test_discovery_needs_no_authentication(
        self,
        client: TestClient,
        transport,
    ) -> None:
        """Public map data, and the applicant may not be signed in yet."""
        transport(lambda url, data: (200, {"elements": []}))

        response = client.get(
            "/api/nearby-banks",
            params={"latitude": ORIGIN[0], "longitude": ORIGIN[1]},
        )

        assert response.status_code == 200
