"""Read-only channel-partner API routes."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import User
from app.schemas.partner import (
    NearbyPartnerResponse,
    PartnerResponse,
    RecommendedPartnerResponse,
    RoutedPartnerResponse,
)
from app.services import partner_routing_service, partner_service

router = APIRouter(prefix="/api/partners", tags=["Partners"])
DatabaseSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]


@router.get(
    "/nearby",
    response_model=list[NearbyPartnerResponse],
    summary="Find nearby available partners",
    description=(
        "Uses the deterministic Haversine formula. Only active partners with "
        "remaining quota and within the requested radius are returned."
    ),
)
def find_nearby_partners(
    session: DatabaseSession,
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
        Query(gt=0, description="Maximum search radius in kilometres."),
    ],
    limit: Annotated[
        int | None,
        Query(gt=0, le=100, description="Optional maximum number of results."),
    ] = None,
) -> list[NearbyPartnerResponse]:
    """Return nearby available channel partners ordered by distance."""
    return partner_service.find_nearby_partners(
        session,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
        limit=limit,
    )


@router.get(
    "/recommended",
    response_model=list[RecommendedPartnerResponse],
    summary="Recommend partners for authenticated user",
    description=(
        "Uses only the Bearer token user's stored coordinates. Results are active, "
        "have positive quota, fall within the radius, and are ordered by distance."
    ),
    responses={
        400: {"description": "The authenticated user has no stored location."},
        401: {"description": "Missing or invalid access token."},
    },
)
def recommend_partners(
    session: DatabaseSession,
    current_user: CurrentUser,
    radius_km: Annotated[
        float | None,
        Query(
            gt=0,
            le=20_000,
            description="Optional radius; defaults to server configuration.",
        ),
    ] = None,
    limit: Annotated[
        int | None,
        Query(gt=0, le=100, description="Optional maximum number of results."),
    ] = None,
) -> list[RecommendedPartnerResponse]:
    """Return deterministic distance-ranked recommendations for the token user."""
    try:
        return partner_service.recommend_partners_for_user(
            session,
            current_user,
            radius_km=radius_km,
            limit=limit,
        )
    except partner_service.UserLocationRequiredError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User location is not configured",
        ) from None


@router.get(
    "/routed",
    response_model=list[RoutedPartnerResponse],
    summary="Route applicant to the best nearby partner",
    description=(
        "Two-stage deterministic routing. First the K geographically nearest "
        "active partners with remaining quota are retrieved by Haversine "
        "distance from the Bearer-token user's stored coordinates; those K are "
        "then ranked by a weighted Partner Health Score over NPA, remaining "
        "quota, and distance. No trained model is involved."
    ),
    responses={
        400: {"description": "The authenticated user has no stored location."},
        401: {"description": "Missing or invalid access token."},
    },
)
def route_partners(
    session: DatabaseSession,
    current_user: CurrentUser,
    k: Annotated[
        int,
        Query(
            gt=0,
            le=partner_routing_service.MAX_K,
            description="How many nearest partners to consider before health ranking.",
        ),
    ] = partner_routing_service.DEFAULT_K,
) -> list[RoutedPartnerResponse]:
    """Return the K nearest eligible partners ordered by health score."""
    try:
        return partner_routing_service.route_partners_for_user(
            session,
            current_user,
            k=k,
        )
    except partner_service.UserLocationRequiredError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User location is not configured",
        ) from None


@router.get(
    "",
    response_model=list[PartnerResponse],
    summary="List channel partners",
    description=(
        "Returns active partners by default. Zero-quota partners remain visible "
        "in this general listing."
    ),
)
def list_partners(
    session: DatabaseSession,
    is_active: Annotated[
        bool | None,
        Query(description="Filter active or inactive partners; defaults to active."),
    ] = True,
) -> list[PartnerResponse]:
    """Return stored channel partners."""
    return partner_service.list_partners(session, is_active=is_active)


@router.get(
    "/{partner_id}",
    response_model=PartnerResponse,
    summary="Get a channel partner",
    description="Returns one stored channel partner branch.",
    responses={404: {"description": "Partner not found."}},
)
def get_partner(
    session: DatabaseSession,
    partner_id: Annotated[int, Path(gt=0, description="Partner primary key.")],
) -> PartnerResponse:
    """Return one partner or a clean 404 response."""
    partner = partner_service.get_partner(session, partner_id)
    if partner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Partner not found",
        )
    return partner
