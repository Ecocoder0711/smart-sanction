"""Two-stage geo-spatial channel-partner routing.

Stage 1 retrieves the K geographically nearest eligible partners using the
repository's existing Haversine helper. This is exact brute-force
nearest-neighbour retrieval over the partner table -- there is no trained
model and no persisted artifact.

Stage 2 ranks only those K candidates by a Partner Health Score, which is a
deterministic weighted score over fields already stored on the partner
record (NPA, remaining quota, distance) -- again, not a trained model.

Proximity therefore defines the candidate neighbourhood before any
operational ranking is applied: a healthier but farther partner cannot
displace a nearer one it never competed with.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import User
from app.schemas.partner import RoutedPartnerResponse
from app.services import partner_service

DEFAULT_K = 5
MAX_K = 50

# Larger than the maximum possible great-circle distance on Earth
# (~20,015 km), so Stage 1 is bounded by K alone and never by a radius.
GLOBAL_SEARCH_RADIUS_KM = 20_100.0

# How many nearest partners /api/match considers before health ranking. Kept
# separate from DEFAULT_K so tuning the matching flow cannot silently change
# the /api/partners/routed default, and vice versa.
MATCH_PARTNER_K = 5

# Partner Health Score reference bounds. Fixed prototype constants derived
# from the current synthetic partner dataset (backend/seed/partners.py:
# npa 0.75-14.75%, quota 0-6,000,000) rather than fit per request, so a
# partner's score never depends on which other partners it was routed with.
# Revisit when real channel-partner data replaces the synthetic seed.
NPA_MAX_REFERENCE = 15.0
QUOTA_REFERENCE = 6_000_000.0
PROXIMITY_REFERENCE_KM = 50.0

NPA_WEIGHT = 0.40
CAPACITY_WEIGHT = 0.30
PROXIMITY_WEIGHT = 0.30


def calculate_health_score(
    *,
    npa_percentage: float,
    quota_remaining: float,
    distance_km: float,
) -> float:
    """Return a deterministic 0-1 health score for one partner.

    Three normalised components, each clamped to [0, 1]:
      - npa_health: lower non-performing-asset percentage is healthier
      - capacity:   more remaining quota can absorb more applications
      - proximity:  a closer branch is cheaper and faster to route to
    """
    npa_health = 1.0 - min(max(npa_percentage, 0.0) / NPA_MAX_REFERENCE, 1.0)
    capacity = min(max(quota_remaining, 0.0) / QUOTA_REFERENCE, 1.0)
    proximity = max(0.0, 1.0 - max(distance_km, 0.0) / PROXIMITY_REFERENCE_KM)

    score = (
        NPA_WEIGHT * npa_health
        + CAPACITY_WEIGHT * capacity
        + PROXIMITY_WEIGHT * proximity
    )
    return min(1.0, max(0.0, score))


def route_partners_for_user(
    session: Session,
    user: User,
    *,
    k: int = DEFAULT_K,
    radius_km: float | None = None,
) -> list[RoutedPartnerResponse]:
    """Return the K nearest eligible partners, ranked by health score.

    `radius_km` bounds Stage 1's geographic neighbourhood. It defaults to
    GLOBAL_SEARCH_RADIUS_KM, i.e. effectively unbounded, so the result is
    capped by K alone -- that is what /api/partners/routed asks for ("the K
    nearest, wherever they are") and its behaviour is unchanged.

    Callers that must not recommend an unreachable branch pass a real radius
    instead. Without one, a user far from every partner still receives K of
    them: the proximity term saturates beyond PROXIMITY_REFERENCE_KM, so a
    branch 8,000 km away scores no worse than one 60 km away and the health
    score cannot express the difference.

    Raises partner_service.UserLocationRequiredError when the user has no
    stored coordinates, matching the existing recommendation behaviour.
    """
    if user.latitude is None or user.longitude is None:
        raise partner_service.UserLocationRequiredError

    # Stage 1 -- geographic neighbourhood. find_nearby_partners already
    # excludes inactive and zero-quota partners, computes Haversine
    # distance, and orders by (distance_km, id), so taking the first k rows
    # is exactly the K nearest eligible partners inside the radius.
    nearest = partner_service.find_nearby_partners(
        session,
        latitude=float(user.latitude),
        longitude=float(user.longitude),
        radius_km=(
            GLOBAL_SEARCH_RADIUS_KM if radius_km is None else radius_km
        ),
        limit=k,
    )

    # Stage 2 -- operational ranking within that fixed neighbourhood.
    routed = [
        RoutedPartnerResponse(
            **candidate.model_dump(),
            health_score=round(
                calculate_health_score(
                    npa_percentage=float(candidate.npa_percentage),
                    quota_remaining=float(candidate.quota_remaining),
                    distance_km=candidate.distance_km,
                ),
                5,
            ),
        )
        for candidate in nearest
    ]
    routed.sort(key=lambda item: (-item.health_score, item.distance_km, item.id))
    return routed
