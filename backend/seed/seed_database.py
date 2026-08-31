"""Seed PostgreSQL with deterministic synthetic development data."""

import sys

from sqlalchemy.orm import Session

from app.database.session import get_engine
from seed.applications import seed_applications
from seed.common import SeedResult
from seed.partners import seed_partners
from seed.schemes import seed_categories, seed_schemes
from seed.users import seed_users


def _print_result(label: str, result: SeedResult) -> None:
    """Print one concise, idempotency-aware result line."""
    print(
        f"{label}: {result.total} "
        f"(inserted {result.inserted}, existing {result.existing})"
    )


def run_seed() -> dict[str, SeedResult]:
    """Run every seed step in one transaction and return its summary."""
    print("Synthetic seed started...")
    with Session(get_engine()) as session:
        try:
            categories, category_result = seed_categories(session)
            schemes, scheme_result = seed_schemes(session, categories)
            users, user_result = seed_users(session)
            partners, partner_result = seed_partners(session)
            application_result = seed_applications(
                session,
                users,
                schemes,
                partners,
            )
            session.commit()
        except Exception as exc:
            session.rollback()
            print(f"Synthetic seed failed; transaction rolled back: {exc}", file=sys.stderr)
            raise

    results = {
        "Categories": category_result,
        "Schemes": scheme_result,
        "Users": user_result,
        "Partners": partner_result,
        "Applications": application_result,
    }
    for label, result in results.items():
        _print_result(label, result)
    print("Synthetic seed completed successfully.")
    return results


if __name__ == "__main__":
    run_seed()

