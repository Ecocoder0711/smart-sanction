"""Synthetic fictional channel-partner fixtures for geographic testing."""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ChannelPartner
from seed.common import SeedResult

SYNTHETIC_PARTNERS: tuple[dict[str, object], ...] = (
    {"bank_name": "Demo Jan Credit Bank", "branch_code": "DEMO-BHO-001", "latitude": Decimal("23.260500"), "longitude": Decimal("77.413200"), "npa_percentage": Decimal("1.2000"), "quota_remaining": Decimal("2500000.00"), "is_active": True},
    {"bank_name": "Prototype Livelihood Bank", "branch_code": "DEMO-DEL-002", "latitude": Decimal("28.615000"), "longitude": Decimal("77.210200"), "npa_percentage": Decimal("2.4000"), "quota_remaining": Decimal("5000000.00"), "is_active": True},
    {"bank_name": "Sample Cooperative Finance", "branch_code": "DEMO-MUM-003", "latitude": Decimal("19.074800"), "longitude": Decimal("72.879000"), "npa_percentage": Decimal("3.1000"), "quota_remaining": Decimal("0.00"), "is_active": True},
    {"bank_name": "Fictional Growth Bank", "branch_code": "DEMO-RAN-004", "latitude": Decimal("23.345200"), "longitude": Decimal("85.310700"), "npa_percentage": Decimal("4.8000"), "quota_remaining": Decimal("1800000.00"), "is_active": True},
    {"bank_name": "Demo Jan Credit Bank", "branch_code": "DEMO-GUW-005", "latitude": Decimal("26.145300"), "longitude": Decimal("91.737000"), "npa_percentage": Decimal("6.2500"), "quota_remaining": Decimal("900000.00"), "is_active": True},
    {"bank_name": "Prototype Livelihood Bank", "branch_code": "DEMO-LEH-006", "latitude": Decimal("34.151800"), "longitude": Decimal("77.576300"), "npa_percentage": Decimal("2.0500"), "quota_remaining": Decimal("650000.00"), "is_active": False},
    {"bank_name": "Sample Cooperative Finance", "branch_code": "DEMO-JAI-007", "latitude": Decimal("26.913100"), "longitude": Decimal("75.788100"), "npa_percentage": Decimal("7.8000"), "quota_remaining": Decimal("1200000.00"), "is_active": True},
    {"bank_name": "Fictional Growth Bank", "branch_code": "DEMO-HYD-008", "latitude": Decimal("17.386100"), "longitude": Decimal("78.487900"), "npa_percentage": Decimal("1.8500"), "quota_remaining": Decimal("4200000.00"), "is_active": True},
    {"bank_name": "Demo Jan Credit Bank", "branch_code": "DEMO-KOL-009", "latitude": Decimal("22.573500"), "longitude": Decimal("88.365000"), "npa_percentage": Decimal("9.5000"), "quota_remaining": Decimal("750000.00"), "is_active": True},
    {"bank_name": "Prototype Livelihood Bank", "branch_code": "DEMO-BLR-010", "latitude": Decimal("12.972700"), "longitude": Decimal("77.595700"), "npa_percentage": Decimal("2.7500"), "quota_remaining": Decimal("6000000.00"), "is_active": True},
    {"bank_name": "Sample Cooperative Finance", "branch_code": "DEMO-CHE-011", "latitude": Decimal("13.083600"), "longitude": Decimal("80.271600"), "npa_percentage": Decimal("5.6000"), "quota_remaining": Decimal("2100000.00"), "is_active": True},
    {"bank_name": "Fictional Growth Bank", "branch_code": "DEMO-PUN-012", "latitude": Decimal("18.521300"), "longitude": Decimal("73.857600"), "npa_percentage": Decimal("3.9000"), "quota_remaining": Decimal("3300000.00"), "is_active": True},
    {"bank_name": "Demo Jan Credit Bank", "branch_code": "DEMO-LKO-013", "latitude": Decimal("26.847500"), "longitude": Decimal("80.947100"), "npa_percentage": Decimal("14.7500"), "quota_remaining": Decimal("450000.00"), "is_active": True},
    {"bank_name": "Prototype Livelihood Bank", "branch_code": "DEMO-KOC-014", "latitude": Decimal("9.932100"), "longitude": Decimal("76.268200"), "npa_percentage": Decimal("2.2000"), "quota_remaining": Decimal("2750000.00"), "is_active": True},
    {"bank_name": "Sample Cooperative Finance", "branch_code": "DEMO-AHM-015", "latitude": Decimal("23.023400"), "longitude": Decimal("72.572300"), "npa_percentage": Decimal("4.3000"), "quota_remaining": Decimal("0.00"), "is_active": True},
    {"bank_name": "Fictional Growth Bank", "branch_code": "DEMO-PAT-016", "latitude": Decimal("25.595000"), "longitude": Decimal("85.138500"), "npa_percentage": Decimal("8.2000"), "quota_remaining": Decimal("1350000.00"), "is_active": True},
    {"bank_name": "Demo Jan Credit Bank", "branch_code": "DEMO-RAI-017", "latitude": Decimal("21.252300"), "longitude": Decimal("81.630500"), "npa_percentage": Decimal("6.9000"), "quota_remaining": Decimal("980000.00"), "is_active": False},
    {"bank_name": "Prototype Livelihood Bank", "branch_code": "DEMO-BBI-018", "latitude": Decimal("20.297000"), "longitude": Decimal("85.825400"), "npa_percentage": Decimal("1.6000"), "quota_remaining": Decimal("3600000.00"), "is_active": True},
)


def seed_partners(
    session: Session,
) -> tuple[dict[str, ChannelPartner], SeedResult]:
    """Insert missing fictional branches identified by deterministic branch code."""
    branch_codes = [str(item["branch_code"]) for item in SYNTHETIC_PARTNERS]
    existing = {
        partner.branch_code: partner
        for partner in session.scalars(
            select(ChannelPartner).where(ChannelPartner.branch_code.in_(branch_codes))
        )
    }
    inserted = 0
    for item in SYNTHETIC_PARTNERS:
        branch_code = str(item["branch_code"])
        if branch_code not in existing:
            partner = ChannelPartner(**item)
            session.add(partner)
            existing[branch_code] = partner
            inserted += 1
    session.flush()
    return existing, SeedResult(total=len(SYNTHETIC_PARTNERS), inserted=inserted)

