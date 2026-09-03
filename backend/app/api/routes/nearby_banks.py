"""Geographic bank-branch discovery from OpenStreetMap.

Deliberately separate from /api/partners: this endpoint answers "what banks
exist around here", not "where can we route this application". Nothing it
returns is eligible to become an application's partner.
"""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.core.config import get_settings
from app.schemas.nearby_bank import NearbyBankResponse
from app.services import nearby_bank_service

router = APIRouter(prefix="/api/nearby-banks", tags=["Nearby Banks"])


@router.get(
    "",
    response_model=NearbyBankResponse,
    summary="Discover real bank branches near a coordinate",
    description=(
        "Returns real bank branches from OpenStreetMap around the given "
        "point, nearest first. These are map features, not registered "
        "channel partners: they carry no quota, NPA, or Partner Health "
        "Score, and cannot be used as an application's partner. Unnamed "
        "features are omitted and addresses appear only where OpenStreetMap "
        "genuinely has them."
    ),
)
def discover_nearby_banks(
    latitude: Annotated[
        float,
        Query(ge=-90, le=90, description="Origin latitude in decimal degrees."),
    ],
    longitude: Annotated[
        float,
        Query(ge=-180, le=180, description="Origin longitude in decimal degrees."),
    ],
    radius_km: Annotated[
        float,
        Query(gt=0, description="Search radius in kilometres."),
    ] = 5.0,
) -> NearbyBankResponse:
    """Return nearby real bank branches, or 503 if discovery is unavailable."""
    settings = get_settings()
    if radius_km > settings.nearby_bank_max_radius_km:
        # Bounded to keep one request from pulling a city-sized result set
        # through a rate-limited public API.
        raise HTTPException(
            # The ..._ENTITY spelling is deprecated in this Starlette.
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=(
                f"radius_km must not exceed "
                f"{settings.nearby_bank_max_radius_km:g}"
            ),
        )

    try:
        return nearby_bank_service.find_nearby_banks(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
        )
    except nearby_bank_service.NearbyBankUnavailableError as error:
        # A discovery outage is explicitly not a matching outage: the client
        # keeps its registered partners and simply hides this section.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Nearby bank discovery is temporarily unavailable",
        ) from error
