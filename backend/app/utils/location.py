"""Deterministic geographic distance calculations."""

from math import asin, cos, radians, sin, sqrt

EARTH_MEAN_RADIUS_KM = 6371.0088


def haversine_distance_km(
    latitude_1: float,
    longitude_1: float,
    latitude_2: float,
    longitude_2: float,
) -> float:
    """Return great-circle distance between two coordinates in kilometres."""
    latitude_delta = radians(latitude_2 - latitude_1)
    longitude_delta = radians(longitude_2 - longitude_1)
    latitude_1_radians = radians(latitude_1)
    latitude_2_radians = radians(latitude_2)

    haversine = (
        sin(latitude_delta / 2) ** 2
        + cos(latitude_1_radians)
        * cos(latitude_2_radians)
        * sin(longitude_delta / 2) ** 2
    )
    bounded_haversine = min(1.0, max(0.0, haversine))
    central_angle = 2 * asin(sqrt(bounded_haversine))
    return EARTH_MEAN_RADIUS_KM * central_angle
