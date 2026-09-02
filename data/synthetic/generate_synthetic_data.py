"""Generate a bulk fictional dataset for ML prototyping.

Produces 10,000 fictional beneficiary records and 100 fictional channel
partner records as CSV files in this directory. This is a larger,
non-deterministic companion to the small deterministic API demo seed in
backend/seed/ (see docs/ml-integration.md for why the larger corpus exists):
that seed writes ~18 fixed rows straight to PostgreSQL for API/Swagger demos,
while this script writes CSVs sized for training/prototyping the future ML
matching engine. All records are entirely fictional; none describe a real
person, bank, or government scheme.

Usage (from data/, with data/requirements.txt installed):
    python synthetic/generate_synthetic_data.py
"""

from __future__ import annotations

import random
from pathlib import Path

import pandas as pd
from faker import Faker

OUTPUT_DIR = Path(__file__).resolve().parent
BENEFICIARY_COUNT = 10_000
PARTNER_COUNT = 100
RANDOM_SEED = 42

# Matches the category_name values seeded in backend/seed/schemes.py.
CATEGORIES = ("SC", "ST", "OBC", "GENERAL")
GENDERS = ("MALE", "FEMALE", "OTHER")

INDIA_LAT_RANGE = (8.0, 37.0)
INDIA_LON_RANGE = (68.0, 97.0)

# City anchors reused/extended from backend/seed/partners.py so branches
# cluster near real city centers instead of scattering uniformly over India.
PARTNER_CITIES: tuple[tuple[str, float, float], ...] = (
    ("BHO", 23.2600, 77.4130),
    ("DEL", 28.6150, 77.2102),
    ("MUM", 19.0748, 72.8790),
    ("RAN", 23.3452, 85.3107),
    ("GUW", 26.1453, 91.7370),
    ("LEH", 34.1518, 77.5763),
    ("JAI", 26.9131, 75.7881),
    ("HYD", 17.3861, 78.4879),
    ("KOL", 22.5735, 88.3650),
    ("BLR", 12.9727, 77.5957),
    ("CHE", 13.0836, 80.2716),
    ("PUN", 18.5213, 73.8576),
    ("LKO", 26.8475, 80.9471),
    ("KOC", 9.9321, 76.2682),
    ("AHM", 23.0234, 72.5723),
    ("PAT", 25.5950, 85.1385),
    ("RAI", 21.2523, 81.6305),
    ("BBI", 20.2970, 85.8254),
    ("NAG", 21.1458, 79.0882),
    ("IND", 22.7196, 75.8577),
)

# Fictional name fragments only, following the "Demo/Prototype/Sample/
# Fictional" convention already used in backend/seed/partners.py so no
# generated name can be mistaken for a real bank.
BANK_PREFIXES = (
    "Demo",
    "Prototype",
    "Sample",
    "Fictional",
    "Regional",
    "Metro",
    "Rural",
    "National",
    "Urban",
    "Unity",
)
BANK_SUFFIXES = (
    "Jan Credit Bank",
    "Livelihood Bank",
    "Cooperative Finance",
    "Growth Bank",
    "Trust Bank",
    "Microfinance Bank",
    "Rural Credit Union",
    "Enterprise Bank",
)

fake = Faker("en_IN")


def _unique_phone(seen: set[str]) -> str:
    """Return a fictional, unique 10-digit Indian mobile number."""
    while True:
        number = "+91" + str(random.randint(6, 9)) + "".join(
            str(random.randint(0, 9)) for _ in range(9)
        )
        if number not in seen:
            seen.add(number)
            return number


def generate_beneficiaries(count: int) -> pd.DataFrame:
    """Build fictional beneficiary records shaped like the User model.

    Adds desired_loan_amount and previous_default, which the User model
    does not persist but a matching/approval model needs as features.
    """
    seen_phones: set[str] = set()
    rows = []
    for i in range(1, count + 1):
        annual_income = round(random.triangular(80_000, 2_000_000, 300_000), 2)
        rows.append(
            {
                "beneficiary_id": i,
                "full_name": fake.name(),
                "phone": _unique_phone(seen_phones),
                "annual_income": annual_income,
                "category": random.choice(CATEGORIES),
                "gender": random.choice(GENDERS),
                "latitude": round(random.uniform(*INDIA_LAT_RANGE), 6),
                "longitude": round(random.uniform(*INDIA_LON_RANGE), 6),
                "desired_loan_amount": round(
                    random.uniform(20_000, min(3_500_000, annual_income * 4)), 2
                ),
                "previous_default": random.random() < 0.12,
            }
        )
    return pd.DataFrame(rows)


def generate_channel_partners(count: int) -> pd.DataFrame:
    """Build fictional branch records shaped like the ChannelPartner model."""
    rows = []
    for i in range(1, count + 1):
        city_code, base_lat, base_lon = random.choice(PARTNER_CITIES)
        bank_name = f"{random.choice(BANK_PREFIXES)} {random.choice(BANK_SUFFIXES)}"
        rows.append(
            {
                "partner_id": i,
                "bank_name": bank_name,
                "branch_code": f"SYN-{city_code}-{i:03d}",
                "latitude": round(base_lat + random.uniform(-0.05, 0.05), 6),
                "longitude": round(base_lon + random.uniform(-0.05, 0.05), 6),
                "npa_percentage": round(random.uniform(0.5, 15.0), 4),
                "quota_remaining": round(random.uniform(0, 6_000_000), 2),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    """Generate both CSVs deterministically and report what was written."""
    Faker.seed(RANDOM_SEED)
    random.seed(RANDOM_SEED)

    beneficiaries = generate_beneficiaries(BENEFICIARY_COUNT)
    partners = generate_channel_partners(PARTNER_COUNT)

    beneficiaries_path = OUTPUT_DIR / "beneficiaries.csv"
    partners_path = OUTPUT_DIR / "channel_partners.csv"
    beneficiaries.to_csv(beneficiaries_path, index=False)
    partners.to_csv(partners_path, index=False)

    print(f"Wrote {len(beneficiaries)} beneficiary records to {beneficiaries_path}")
    print(f"Wrote {len(partners)} channel partner records to {partners_path}")


if __name__ == "__main__":
    main()
