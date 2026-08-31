"""Import all ORM models so SQLAlchemy and Alembic can discover them."""

from app.models.application import Application
from app.models.partner import ChannelPartner
from app.models.scheme import Scheme
from app.models.scheme_category import SchemeCategory
from app.models.user import User

__all__ = [
    "Application",
    "ChannelPartner",
    "Scheme",
    "SchemeCategory",
    "User",
]

