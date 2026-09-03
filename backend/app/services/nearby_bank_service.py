"""Real bank-branch discovery from OpenStreetMap, mediated and cached.

This is geographic discovery only. It answers "what banks are physically
around this point", using public OpenStreetMap data via the Overpass API. It
says nothing about whether we can route an application to any of them --
that remains the job of the channel-partner router, which is untouched here.

Why the backend calls Overpass instead of the app doing it directly: the
public endpoint allows only two concurrent slots per source IP. A room full
of devices on one venue network would trip that limit. Mediating here makes
us a single client, and the TTL cache collapses repeated nearby requests into
one upstream call.

Nothing here is written to PostgreSQL. OpenStreetMap data is not ours to own,
and a cached copy that outlives the request would go stale silently.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import httpx

from app.core.config import get_settings
from app.schemas.nearby_bank import NearbyBank, NearbyBankResponse
from app.utils.location import haversine_distance_km


class NearbyBankUnavailableError(RuntimeError):
    """Raised when no Overpass endpoint could answer.

    The caller turns this into a 503. It never affects channel-partner
    routing, which reads only our own database.
    """


@dataclass(frozen=True)
class _DiscoveredBank:
    """An OSM feature after parsing, before distance is known.

    Distance depends on the caller's exact coordinates, while the cache is
    keyed on rounded ones, so it is computed per request rather than stored.
    """

    osm_id: str
    name: str
    latitude: float
    longitude: float
    address: str | None


# Cache key coordinates are rounded to this many decimals. Two decimals is
# roughly 1.1 km, which is deliberately coarse: devices standing next to each
# other should share one upstream call. Only the *query centre* is rounded --
# every distance we return is measured from the caller's real coordinates.
_CACHE_COORDINATE_DECIMALS = 2

# OpenStreetMap's usage policy requires a descriptive User-Agent identifying
# the application. This is not optional politeness: without it the public
# Overpass endpoint rejects the request, answering with a non-JSON body or
# simply holding the connection until it times out. httpx sends no
# User-Agent of its own, which is why this header is set explicitly.
_USER_AGENT = "smart-sanction/0.1 (SIH Stage 2 prototype)"

# How many branches one response may carry. A 40 km radius is modest in a
# small city -- Dehradun returns 34 -- but dense in a metro: live queries
# returned 1,041 named branches for Delhi and 1,493 for Bengaluru. Plotting
# those on a phone map is unusable, so the list is bounded.
#
# The cap is applied only after every branch has been distance-filtered and
# sorted, so it always yields the N genuinely nearest. Truncating earlier --
# for instance with Overpass's own `out center N`, which returns an arbitrary
# subset -- would silently drop the closest branch.
MAX_NEARBY_BANK_RESULTS = 50

_cache: dict[tuple[float, float, float], tuple[float, list[_DiscoveredBank]]] = {}
_cache_lock = threading.Lock()

# OSM address tags, in the order they are joined into a display address.
_ADDRESS_TAGS = (
    "addr:housenumber",
    "addr:street",
    "addr:suburb",
    "addr:city",
    "addr:postcode",
)


def _build_query(latitude: float, longitude: float, radius_m: float, timeout_s: int) -> str:
    """Return Overpass QL for banks around a point.

    Both nodes and ways are queried because a bank may be mapped either as a
    point or as a building outline; `out center` gives a way a single
    representative coordinate.
    """
    around = f"(around:{radius_m:.0f},{latitude:.6f},{longitude:.6f})"
    return (
        f"[out:json][timeout:{timeout_s}];"
        f'(node["amenity"="bank"]{around};'
        f'way["amenity"="bank"]{around};);'
        f"out center;"
    )


def _format_address(tags: dict[str, str]) -> str | None:
    """Join whatever address tags exist, or return None.

    Never fabricated: if OSM carries no address for a feature -- which is the
    common case for Indian bank nodes -- the applicant is shown no address
    rather than a reverse-geocoded guess.
    """
    parts = [tags[tag].strip() for tag in _ADDRESS_TAGS if tags.get(tag, "").strip()]
    return ", ".join(parts) if parts else None


def _parse_elements(payload: object) -> list[_DiscoveredBank]:
    """Turn an Overpass JSON body into banks we are willing to show.

    Anything without a usable name or coordinate pair is dropped. An unnamed
    bank node is real data, but "Bank" on a map pin tells an applicant
    nothing, so it is not rendered at all.
    """
    if not isinstance(payload, dict):
        return []
    elements = payload.get("elements")
    if not isinstance(elements, list):
        return []

    discovered: list[_DiscoveredBank] = []
    seen: set[str] = set()
    for element in elements:
        if not isinstance(element, dict):
            continue
        tags = element.get("tags")
        tags = tags if isinstance(tags, dict) else {}

        name = str(tags.get("name", "")).strip()
        if not name:
            continue

        centre = element.get("center")
        centre = centre if isinstance(centre, dict) else {}
        latitude = element.get("lat", centre.get("lat"))
        longitude = element.get("lon", centre.get("lon"))
        if not isinstance(latitude, (int, float)) or not isinstance(
            longitude, (int, float)
        ):
            continue
        if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
            continue

        osm_id = f"{element.get('type', 'node')}/{element.get('id')}"
        if osm_id in seen:
            continue
        seen.add(osm_id)

        discovered.append(
            _DiscoveredBank(
                osm_id=osm_id,
                name=name,
                latitude=float(latitude),
                longitude=float(longitude),
                address=_format_address(tags),
            )
        )
    return discovered


def _fetch(query: str) -> list[_DiscoveredBank]:
    """Query Overpass, falling back to the mirror, and parse the result.

    The mirror is tried on transport errors and on 5xx/429 -- a rate-limited
    primary is exactly when the fallback earns its place. A 4xx that is not
    429 means our own query is wrong, so retrying it elsewhere would only
    waste the demo's time.
    """
    settings = get_settings()
    endpoints = [settings.overpass_primary_url, settings.overpass_fallback_url]
    last_error: Exception | None = None

    for endpoint in endpoints:
        if not endpoint:
            continue
        try:
            with httpx.Client(
                timeout=settings.overpass_timeout_seconds,
                headers={"User-Agent": _USER_AGENT},
            ) as client:
                response = client.post(endpoint, data={"data": query})
            if response.status_code == 429 or response.status_code >= 500:
                last_error = httpx.HTTPStatusError(
                    f"Overpass returned {response.status_code}",
                    request=response.request,
                    response=response,
                )
                continue
            response.raise_for_status()
            return _parse_elements(response.json())
        except (httpx.HTTPError, ValueError) as error:
            last_error = error
            continue

    raise NearbyBankUnavailableError(
        "No Overpass endpoint answered the bank discovery query"
    ) from last_error


def _cache_key(
    latitude: float,
    longitude: float,
    radius_km: float,
) -> tuple[float, float, float]:
    return (
        round(latitude, _CACHE_COORDINATE_DECIMALS),
        round(longitude, _CACHE_COORDINATE_DECIMALS),
        round(radius_km, 1),
    )


def _cached(key: tuple[float, float, float]) -> list[_DiscoveredBank] | None:
    ttl = get_settings().overpass_cache_ttl_seconds
    if ttl <= 0:
        return None
    with _cache_lock:
        entry = _cache.get(key)
        if entry is None:
            return None
        stored_at, banks = entry
        if time.monotonic() - stored_at > ttl:
            # Expired: drop it so a stale entry cannot be served later.
            _cache.pop(key, None)
            return None
        return banks


def _store(key: tuple[float, float, float], banks: list[_DiscoveredBank]) -> None:
    if get_settings().overpass_cache_ttl_seconds <= 0:
        return
    with _cache_lock:
        _cache[key] = (time.monotonic(), banks)


def clear_cache() -> None:
    """Empty the discovery cache. Used by tests to isolate cases."""
    with _cache_lock:
        _cache.clear()


def find_nearby_banks(
    *,
    latitude: float,
    longitude: float,
    radius_km: float,
) -> NearbyBankResponse:
    """Return real bank branches around a point, nearest first.

    Distances are Haversine from the caller's own coordinates -- the same
    formula the partner router uses -- and the radius is applied to those
    exact distances, so a coarse cache key can never widen the result.

    Raises NearbyBankUnavailableError when no endpoint answers.
    """
    key = _cache_key(latitude, longitude, radius_km)
    discovered = _cached(key)
    was_cached = discovered is not None

    if discovered is None:
        settings = get_settings()
        query = _build_query(
            key[0],
            key[1],
            radius_km * 1000,
            int(settings.overpass_timeout_seconds) or 1,
        )
        discovered = _fetch(query)
        _store(key, discovered)

    items: list[NearbyBank] = []
    for bank in discovered:
        distance_km = haversine_distance_km(
            latitude,
            longitude,
            bank.latitude,
            bank.longitude,
        )
        if distance_km > radius_km:
            continue
        items.append(
            NearbyBank(
                osm_id=bank.osm_id,
                name=bank.name,
                latitude=bank.latitude,
                longitude=bank.longitude,
                distance_km=round(distance_km, 3),
                address=bank.address,
            )
        )

    # Sort before capping, so the cap keeps the nearest branches rather than
    # whichever ones OpenStreetMap happened to list first. osm_id breaks ties
    # deterministically: the same query returns the same rows every time.
    items.sort(key=lambda bank: (bank.distance_km, bank.osm_id))

    discovered = len(items)
    capped = discovered > MAX_NEARBY_BANK_RESULTS
    if capped:
        items = items[:MAX_NEARBY_BANK_RESULTS]

    return NearbyBankResponse(
        items=items,
        total=len(items),
        discovered=discovered,
        capped=capped,
        cached=was_cached,
    )
