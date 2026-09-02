"""Synthetic scheme-category and scheme fixtures.

These records are fictional and are not official government scheme data.
"""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Scheme, SchemeCategory
from seed.common import SeedResult

SYNTHETIC_CATEGORIES: tuple[dict[str, str], ...] = (
    {
        "category_name": "SC",
        "description": "SYNTHETIC/DEMO category for prototype eligibility testing only.",
    },
    {
        "category_name": "ST",
        "description": "SYNTHETIC/DEMO category for prototype eligibility testing only.",
    },
    {
        "category_name": "OBC",
        "description": "SYNTHETIC/DEMO category for prototype eligibility testing only.",
    },
    {
        "category_name": "GENERAL",
        "description": "SYNTHETIC/DEMO category for prototype eligibility testing only.",
    },
    {
        "category_name": "ANY",
        "description": "SYNTHETIC/DEMO category-unrestricted eligibility marker.",
    },
)

SYNTHETIC_SCHEMES: tuple[dict[str, object], ...] = (
    {
        "scheme_name": "Demo Community Enterprise Starter",
        "category_name": "SC",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("300000.00"),
        "interest_rate": Decimal("4.5000"),
        "moratorium_months": 3,
        "max_income_limit": Decimal("250000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional small-enterprise starter credit.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Community Growth Credit",
        "category_name": "SC",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("1200000.00"),
        "interest_rate": Decimal("6.2500"),
        "moratorium_months": 6,
        "max_income_limit": Decimal("600000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional growth-stage enterprise credit.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Tribal Livelihood Microcredit",
        "category_name": "ST",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("200000.00"),
        "interest_rate": Decimal("3.7500"),
        "moratorium_months": 6,
        "max_income_limit": Decimal("220000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional livelihood microcredit product.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Tribal Enterprise Expansion",
        "category_name": "ST",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("1500000.00"),
        "interest_rate": Decimal("7.0000"),
        "moratorium_months": 12,
        "max_income_limit": Decimal("750000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional enterprise expansion facility.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Artisan Opportunity Fund",
        "category_name": "OBC",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("500000.00"),
        "interest_rate": Decimal("5.2500"),
        "moratorium_months": 4,
        "max_income_limit": Decimal("400000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional artisan working-capital fund.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Enterprise Business Boost",
        "category_name": "OBC",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("2000000.00"),
        "interest_rate": Decimal("7.2500"),
        "moratorium_months": 9,
        "max_income_limit": Decimal("900000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional medium-enterprise credit line.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Universal Microenterprise Loan",
        "category_name": "GENERAL",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("350000.00"),
        "interest_rate": Decimal("8.0000"),
        "moratorium_months": 2,
        "max_income_limit": Decimal("500000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional general microenterprise loan.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Innovation Venture Credit",
        "category_name": "GENERAL",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("3000000.00"),
        "interest_rate": Decimal("9.5000"),
        "moratorium_months": 6,
        "max_income_limit": Decimal("1500000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional higher-value innovation credit.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Women Entrepreneur Starter",
        "category_name": "ANY",
        "gender_eligibility": "FEMALE",
        "max_loan_limit": Decimal("600000.00"),
        "interest_rate": Decimal("4.2500"),
        "moratorium_months": 6,
        "max_income_limit": Decimal("450000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional women-led startup credit.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Women Growth Capital",
        "category_name": "SC",
        "gender_eligibility": "FEMALE",
        "max_loan_limit": Decimal("2500000.00"),
        "interest_rate": Decimal("6.5000"),
        "moratorium_months": 12,
        "max_income_limit": Decimal("1200000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional women-led growth capital facility.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Inclusive Livelihood Support",
        "category_name": "ANY",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("400000.00"),
        "interest_rate": Decimal("4.7500"),
        "moratorium_months": 5,
        "max_income_limit": Decimal("350000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional livelihood support credit.",
        "is_active": True,
    },
    {
        "scheme_name": "Demo Inclusive Enterprise Accelerator",
        "category_name": "GENERAL",
        "gender_eligibility": "ANY",
        "max_loan_limit": Decimal("1800000.00"),
        "interest_rate": Decimal("7.5000"),
        "moratorium_months": 10,
        "max_income_limit": Decimal("1000000.00"),
        "description": "SYNTHETIC/DEMO ONLY: fictional accelerator credit; inactive test case.",
        "is_active": False,
    },
)


def seed_categories(
    session: Session,
) -> tuple[dict[str, SchemeCategory], SeedResult]:
    """Insert missing deterministic categories and return them by name."""
    names = [item["category_name"] for item in SYNTHETIC_CATEGORIES]
    existing = {
        category.category_name: category
        for category in session.scalars(
            select(SchemeCategory).where(SchemeCategory.category_name.in_(names))
        )
    }
    inserted = 0
    for item in SYNTHETIC_CATEGORIES:
        name = item["category_name"]
        if name not in existing:
            category = SchemeCategory(**item)
            session.add(category)
            existing[name] = category
            inserted += 1
    session.flush()
    return existing, SeedResult(total=len(SYNTHETIC_CATEGORIES), inserted=inserted)


def seed_schemes(
    session: Session,
    categories: dict[str, SchemeCategory],
) -> tuple[dict[str, Scheme], SeedResult]:
    """Insert missing deterministic schemes and return them by name."""
    names = [str(item["scheme_name"]) for item in SYNTHETIC_SCHEMES]
    existing = {
        scheme.scheme_name: scheme
        for scheme in session.scalars(
            select(Scheme).where(Scheme.scheme_name.in_(names))
        )
    }
    inserted = 0
    for item in SYNTHETIC_SCHEMES:
        scheme_name = str(item["scheme_name"])
        if scheme_name in existing:
            continue
        values = dict(item)
        category_name = str(values.pop("category_name"))
        scheme = Scheme(category_id=categories[category_name].id, **values)
        session.add(scheme)
        existing[scheme_name] = scheme
        inserted += 1
    session.flush()
    return existing, SeedResult(total=len(SYNTHETIC_SCHEMES), inserted=inserted)
