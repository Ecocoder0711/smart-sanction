"""Synthetic applicant fixtures containing no real personal information."""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import User
from seed.common import SeedResult

SYNTHETIC_USERS: tuple[dict[str, object], ...] = (
    {"full_name": "Demo Applicant 01", "phone": "9000000001", "annual_income": Decimal("90000.00"), "category": "SC", "gender": "FEMALE", "latitude": Decimal("23.259900"), "longitude": Decimal("77.412600"), "password_hash": None},
    {"full_name": "Demo Applicant 02", "phone": "9000000002", "annual_income": Decimal("240000.00"), "category": "SC", "gender": "MALE", "latitude": Decimal("28.613900"), "longitude": Decimal("77.209000"), "password_hash": None},
    {"full_name": "Demo Applicant 03", "phone": "9000000003", "annual_income": Decimal("680000.00"), "category": "SC", "gender": "OTHER", "latitude": Decimal("19.076000"), "longitude": Decimal("72.877700"), "password_hash": None},
    {"full_name": "Demo Applicant 04", "phone": "9000000004", "annual_income": Decimal("110000.00"), "category": "ST", "gender": "MALE", "latitude": Decimal("23.344100"), "longitude": Decimal("85.309600"), "password_hash": None},
    {"full_name": "Demo Applicant 05", "phone": "9000000005", "annual_income": Decimal("360000.00"), "category": "ST", "gender": "FEMALE", "latitude": Decimal("26.144500"), "longitude": Decimal("91.736200"), "password_hash": None},
    {"full_name": "Demo Applicant 06", "phone": "9000000006", "annual_income": Decimal("820000.00"), "category": "ST", "gender": "OTHER", "latitude": Decimal("34.152600"), "longitude": Decimal("77.577100"), "password_hash": None},
    {"full_name": "Demo Applicant 07", "phone": "9000000007", "annual_income": Decimal("150000.00"), "category": "OBC", "gender": "MALE", "latitude": Decimal("26.912400"), "longitude": Decimal("75.787300"), "password_hash": None},
    {"full_name": "Demo Applicant 08", "phone": "9000000008", "annual_income": Decimal("420000.00"), "category": "OBC", "gender": "FEMALE", "latitude": Decimal("17.385000"), "longitude": Decimal("78.486700"), "password_hash": None},
    {"full_name": "Demo Applicant 09", "phone": "9000000009", "annual_income": Decimal("980000.00"), "category": "OBC", "gender": "OTHER", "latitude": Decimal("22.572600"), "longitude": Decimal("88.363900"), "password_hash": None},
    {"full_name": "Demo Applicant 10", "phone": "9000000010", "annual_income": Decimal("210000.00"), "category": "GENERAL", "gender": "MALE", "latitude": Decimal("12.971600"), "longitude": Decimal("77.594600"), "password_hash": None},
    {"full_name": "Demo Applicant 11", "phone": "9000000011", "annual_income": Decimal("720000.00"), "category": "GENERAL", "gender": "FEMALE", "latitude": Decimal("13.082700"), "longitude": Decimal("80.270700"), "password_hash": None},
    {"full_name": "Demo Applicant 12", "phone": "9000000012", "annual_income": Decimal("1800000.00"), "category": "GENERAL", "gender": "OTHER", "latitude": Decimal("18.520400"), "longitude": Decimal("73.856700"), "password_hash": None},
    {"full_name": "Demo Applicant 13", "phone": "9000000013", "annual_income": Decimal("130000.00"), "category": "GENERAL", "gender": "FEMALE", "latitude": Decimal("26.846700"), "longitude": Decimal("80.946200"), "password_hash": None},
    {"full_name": "Demo Applicant 14", "phone": "9000000014", "annual_income": Decimal("510000.00"), "category": "SC", "gender": "FEMALE", "latitude": Decimal("9.931200"), "longitude": Decimal("76.267300"), "password_hash": None},
    {"full_name": "Demo Applicant 15", "phone": "9000000015", "annual_income": Decimal("1150000.00"), "category": "OBC", "gender": "FEMALE", "latitude": Decimal("23.022500"), "longitude": Decimal("72.571400"), "password_hash": None},
    {"full_name": "Demo Applicant 16", "phone": "9000000016", "annual_income": Decimal("175000.00"), "category": "GENERAL", "gender": "MALE", "latitude": Decimal("25.594100"), "longitude": Decimal("85.137600"), "password_hash": None},
    {"full_name": "Demo Applicant 17", "phone": "9000000017", "annual_income": Decimal("460000.00"), "category": "ST", "gender": "FEMALE", "latitude": Decimal("21.251400"), "longitude": Decimal("81.629600"), "password_hash": None},
    {"full_name": "Demo Applicant 18", "phone": "9000000018", "annual_income": Decimal("1050000.00"), "category": "OBC", "gender": "OTHER", "latitude": Decimal("20.296100"), "longitude": Decimal("85.824500"), "password_hash": None},
)


def seed_users(session: Session) -> tuple[dict[str, User], SeedResult]:
    """Insert missing users identified by their reserved synthetic phone number."""
    phones = [str(item["phone"]) for item in SYNTHETIC_USERS]
    existing = {
        user.phone: user
        for user in session.scalars(select(User).where(User.phone.in_(phones)))
    }
    inserted = 0
    for item in SYNTHETIC_USERS:
        phone = str(item["phone"])
        if phone not in existing:
            user = User(**item)
            session.add(user)
            existing[phone] = user
            inserted += 1
    session.flush()
    return existing, SeedResult(total=len(SYNTHETIC_USERS), inserted=inserted)
