"""Synthetic loan-application fixtures with deliberately absent ML outputs."""

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.enums import ApplicationStatus
from app.models import Application, ChannelPartner, Scheme, User
from seed.common import SeedResult

SYNTHETIC_APPLICATIONS: tuple[dict[str, object], ...] = (
    {"user_phone": "9000000001", "scheme_name": "Demo Community Enterprise Starter", "branch_code": "DEMO-BHO-001", "requested_amount": Decimal("150000.00"), "application_date": datetime(2026, 8, 1, 9, 0, tzinfo=timezone.utc), "status": ApplicationStatus.SUBMITTED.value},
    {"user_phone": "9000000002", "scheme_name": "Demo Community Growth Credit", "branch_code": "DEMO-DEL-002", "requested_amount": Decimal("500000.00"), "application_date": datetime(2026, 8, 2, 9, 30, tzinfo=timezone.utc), "status": ApplicationStatus.UNDER_REVIEW.value},
    {"user_phone": "9000000003", "scheme_name": "Demo Community Enterprise Starter", "branch_code": "DEMO-MUM-003", "requested_amount": Decimal("400000.00"), "application_date": datetime(2026, 8, 3, 10, 0, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000004", "scheme_name": "Demo Tribal Livelihood Microcredit", "branch_code": "DEMO-RAN-004", "requested_amount": Decimal("100000.00"), "application_date": datetime(2026, 8, 4, 10, 30, tzinfo=timezone.utc), "status": ApplicationStatus.APPROVED.value},
    {"user_phone": "9000000005", "scheme_name": "Demo Tribal Enterprise Expansion", "branch_code": "DEMO-GUW-005", "requested_amount": Decimal("650000.00"), "application_date": datetime(2026, 8, 5, 11, 0, tzinfo=timezone.utc), "status": ApplicationStatus.UNDER_REVIEW.value},
    {"user_phone": "9000000006", "scheme_name": "Demo Tribal Enterprise Expansion", "branch_code": "DEMO-LEH-006", "requested_amount": Decimal("1400000.00"), "application_date": datetime(2026, 8, 6, 11, 30, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000007", "scheme_name": "Demo Artisan Opportunity Fund", "branch_code": "DEMO-JAI-007", "requested_amount": Decimal("250000.00"), "application_date": datetime(2026, 8, 7, 12, 0, tzinfo=timezone.utc), "status": ApplicationStatus.COMPLETED.value},
    {"user_phone": "9000000008", "scheme_name": "Demo Enterprise Business Boost", "branch_code": "DEMO-HYD-008", "requested_amount": Decimal("800000.00"), "application_date": datetime(2026, 8, 8, 12, 30, tzinfo=timezone.utc), "status": ApplicationStatus.APPROVED.value},
    {"user_phone": "9000000009", "scheme_name": "Demo Artisan Opportunity Fund", "branch_code": "DEMO-KOL-009", "requested_amount": Decimal("550000.00"), "application_date": datetime(2026, 8, 9, 13, 0, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000010", "scheme_name": "Demo Universal Microenterprise Loan", "branch_code": "DEMO-BLR-010", "requested_amount": Decimal("200000.00"), "application_date": datetime(2026, 8, 10, 13, 30, tzinfo=timezone.utc), "status": ApplicationStatus.SUBMITTED.value},
    {"user_phone": "9000000011", "scheme_name": "Demo Innovation Venture Credit", "branch_code": "DEMO-CHE-011", "requested_amount": Decimal("1000000.00"), "application_date": datetime(2026, 8, 11, 14, 0, tzinfo=timezone.utc), "status": ApplicationStatus.UNDER_REVIEW.value},
    {"user_phone": "9000000012", "scheme_name": "Demo Innovation Venture Credit", "branch_code": "DEMO-PUN-012", "requested_amount": Decimal("2500000.00"), "application_date": datetime(2026, 8, 12, 14, 30, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000013", "scheme_name": "Demo Women Entrepreneur Starter", "branch_code": "DEMO-LKO-013", "requested_amount": Decimal("300000.00"), "application_date": datetime(2026, 8, 13, 15, 0, tzinfo=timezone.utc), "status": ApplicationStatus.APPROVED.value},
    {"user_phone": "9000000014", "scheme_name": "Demo Women Growth Capital", "branch_code": "DEMO-KOC-014", "requested_amount": Decimal("1200000.00"), "application_date": datetime(2026, 8, 14, 15, 30, tzinfo=timezone.utc), "status": ApplicationStatus.UNDER_REVIEW.value},
    {"user_phone": "9000000015", "scheme_name": "Demo Women Entrepreneur Starter", "branch_code": "DEMO-AHM-015", "requested_amount": Decimal("600000.00"), "application_date": datetime(2026, 8, 15, 16, 0, tzinfo=timezone.utc), "status": ApplicationStatus.COMPLETED.value},
    {"user_phone": "9000000016", "scheme_name": "Demo Inclusive Livelihood Support", "branch_code": "DEMO-PAT-016", "requested_amount": Decimal("180000.00"), "application_date": datetime(2026, 8, 16, 16, 30, tzinfo=timezone.utc), "status": ApplicationStatus.SUBMITTED.value},
    {"user_phone": "9000000017", "scheme_name": "Demo Inclusive Enterprise Accelerator", "branch_code": "DEMO-RAI-017", "requested_amount": Decimal("700000.00"), "application_date": datetime(2026, 8, 17, 17, 0, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000018", "scheme_name": "Demo Inclusive Enterprise Accelerator", "branch_code": "DEMO-BBI-018", "requested_amount": Decimal("1500000.00"), "application_date": datetime(2026, 8, 18, 17, 30, tzinfo=timezone.utc), "status": ApplicationStatus.REJECTED.value},
    {"user_phone": "9000000001", "scheme_name": "Demo Community Growth Credit", "branch_code": "DEMO-BHO-001", "requested_amount": Decimal("900000.00"), "application_date": datetime(2026, 8, 19, 9, 15, tzinfo=timezone.utc), "status": ApplicationStatus.UNDER_REVIEW.value},
    {"user_phone": "9000000013", "scheme_name": "Demo Women Growth Capital", "branch_code": "DEMO-LKO-013", "requested_amount": Decimal("2000000.00"), "application_date": datetime(2026, 8, 20, 9, 45, tzinfo=timezone.utc), "status": ApplicationStatus.APPROVED.value},
)


def seed_applications(
    session: Session,
    users: dict[str, User],
    schemes: dict[str, Scheme],
    partners: dict[str, ChannelPartner],
) -> SeedResult:
    """Insert missing applications using deterministic reference/date keys."""
    seed_dates = [item["application_date"] for item in SYNTHETIC_APPLICATIONS]
    existing_keys = {
        (item.user_id, item.scheme_id, item.partner_id, item.application_date)
        for item in session.scalars(
            select(Application).where(Application.application_date.in_(seed_dates))
        )
    }
    inserted = 0
    for item in SYNTHETIC_APPLICATIONS:
        user = users[str(item["user_phone"])]
        scheme = schemes[str(item["scheme_name"])]
        partner = partners[str(item["branch_code"])]
        application_date = item["application_date"]
        key = (user.id, scheme.id, partner.id, application_date)
        if key in existing_keys:
            continue
        application = Application(
            user_id=user.id,
            scheme_id=scheme.id,
            partner_id=partner.id,
            requested_amount=item["requested_amount"],
            application_date=application_date,
            status=str(item["status"]),
            ml_match_score=None,
            ml_approval_probability=None,
        )
        session.add(application)
        existing_keys.add(key)
        inserted += 1
    session.flush()
    return SeedResult(total=len(SYNTHETIC_APPLICATIONS), inserted=inserted)
