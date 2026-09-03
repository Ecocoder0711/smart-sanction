"""Schemas for real bank branches discovered from OpenStreetMap.

These are *not* channel partners. A discovered bank is a public map feature:
we know where it is and what it is called, and nothing about its operational
health. It therefore carries no quota, no NPA, and no Partner Health Score,
and it can never become an application's `partner_id`.
"""

from pydantic import BaseModel, ConfigDict, Field


class NearbyBank(BaseModel):
    """One real bank branch from OpenStreetMap.

    `osm_id` is the stable OSM identifier in `<type>/<id>` form (for example
    `node/1234567`), which is what OSM itself uses to address a feature and
    keeps node and way ids from colliding.
    """

    model_config = ConfigDict(extra="forbid")

    osm_id: str
    name: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    distance_km: float = Field(ge=0)

    # Absent whenever OSM has no address tags for the feature. Most Indian
    # bank nodes carry none, so this is null far more often than not and is
    # never synthesised from the coordinates.
    address: str | None = None


class NearbyBankResponse(BaseModel):
    """Discovery result, ordered nearest-first.

    `source` names the upstream so the client can attribute the data, and
    `cached` says whether this answer avoided an upstream call.

    `total` counts what is in `items`, while `discovered` counts everything
    found inside the radius. They differ only when `capped` is true, and the
    pair exists so the screen can say "the 50 nearest of 1,041" rather than
    presenting a truncated list as if it were the whole neighbourhood.
    """

    model_config = ConfigDict(extra="forbid")

    items: list[NearbyBank]
    total: int = Field(ge=0)
    discovered: int = Field(ge=0)
    capped: bool = False
    source: str = "openstreetmap"
    cached: bool = False
