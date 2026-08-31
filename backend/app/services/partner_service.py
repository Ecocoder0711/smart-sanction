"""Channel-partner query and distance services."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import ChannelPartner, User
from app.schemas.partner import (
    NearbyPartnerResponse,
    PartnerResponse,
    RecommendedPartnerResponse,
)
from app.utils.location import haversine_distance_km


def list_partners(
    session: Session,
    *,
    is_active: bool | None = True,
) -> list[ChannelPartner]:
    """Return partners, active by default, in deterministic order."""
    statement = select(ChannelPartner)
    if is_active is not None:
        statement = statement.where(ChannelPartner.is_active.is_(is_active))
    statement = statement.order_by(
        ChannelPartner.bank_name.asc(),
        ChannelPartner.branch_code.asc(),
        ChannelPartner.id.asc(),
    )
    return list(session.scalars(statement))


def get_partner(session: Session, partner_id: int) -> ChannelPartner | None:
    """Return one channel partner by primary key."""
    return session.get(ChannelPartner, partner_id)


def find_nearby_partners(
    session: Session,
    *,
    latitude: float,
    longitude: float,
    radius_km: float,
    limit: int | None = None,
) -> list[NearbyPartnerResponse]:
    """Return available partners inside a radius, sorted by Haversine distance."""
    statement = (
        select(ChannelPartner)
        .where(
            ChannelPartner.is_active.is_(True),
            ChannelPartner.quota_remaining > 0,
        )
        .order_by(ChannelPartner.id.asc())
    )
    results: list[NearbyPartnerResponse] = []
    for partner in session.scalars(statement):
        distance_km = haversine_distance_km(
            latitude,
            longitude,
            float(partner.latitude),
            float(partner.longitude),
        )
        if distance_km <= radius_km:
            partner_data = PartnerResponse.model_validate(partner).model_dump()
            results.append(
                NearbyPartnerResponse(
                    **partner_data,
                    distance_km=round(distance_km, 3),
                )
            )

    results.sort(key=lambda item: (item.distance_km, item.id))
    return results[:limit] if limit is not None else results


class UserLocationRequiredError(ValueError):
    """Raised when a user has no stored coordinates for recommendations."""


def recommend_partners_for_user(
    session: Session,
    user: User,
    *,
    radius_km: float | None = None,
    limit: int | None = None,
) -> list[RecommendedPartnerResponse]:
    """Recommend available partners using only stored user location and distance."""
    if user.latitude is None or user.longitude is None:
        raise UserLocationRequiredError
    effective_radius = (
        radius_km
        if radius_km is not None
        else get_settings().recommended_partner_radius_km
    )
    nearby = find_nearby_partners(
        session,
        latitude=float(user.latitude),
        longitude=float(user.longitude),
        radius_km=effective_radius,
        limit=limit,
    )
    return [RecommendedPartnerResponse.model_validate(item) for item in nearby]
