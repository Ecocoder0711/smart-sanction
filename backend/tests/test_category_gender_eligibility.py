"""Category and gender are independent eligibility dimensions."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Scheme, SchemeCategory, User
from tests.helpers import DEFAULT_PASSWORD, registration_payload


def _scheme_id(client: TestClient, name: str) -> int:
    response = client.get("/api/schemes", params={"is_active": "true"})
    assert response.status_code == 200
    return next(
        item["id"]
        for item in response.json()["items"]
        if item["scheme_name"] == name
    )


def _register_and_login_profile(
    client: TestClient,
    phone: str,
    *,
    category: str,
    gender: str,
) -> dict[str, str]:
    payload = registration_payload(phone)
    payload.update(category=category, gender=gender)
    registration = client.post("/api/auth/register", json=payload)
    assert registration.status_code == 201, registration.text
    login = client.post(
        "/api/auth/login",
        json={"phone": phone, "password": DEFAULT_PASSWORD},
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def _eligibility(
    client: TestClient,
    headers: dict[str, str],
    scheme_name: str,
) -> dict:
    response = client.post(
        "/api/eligibility/check",
        headers=headers,
        json={
            "scheme_id": _scheme_id(client, scheme_name),
            "requested_amount": "100000.00",
        },
    )
    assert response.status_code == 200
    return response.json()


@pytest.mark.parametrize(
    ("phone", "category", "scheme_name"),
    [
        ("9880000071", "SC", "Demo Community Growth Credit"),
        ("9880000072", "ST", "Demo Tribal Enterprise Expansion"),
        ("9880000073", "OBC", "Demo Artisan Opportunity Fund"),
        ("9880000074", "GENERAL", "Demo Universal Microenterprise Loan"),
    ],
)
def test_each_applicant_category_matches_its_specific_scheme(
    client: TestClient,
    phone: str,
    category: str,
    scheme_name: str,
) -> None:
    headers = _register_and_login_profile(
        client,
        phone,
        category=category,
        gender="OTHER",
    )

    result = _eligibility(client, headers, scheme_name)

    assert result["eligible"] is True
    assert "Applicant category is eligible" in result["reasons"]
    assert "Applicant gender is eligible" in result["reasons"]


def test_applicant_does_not_match_different_category(
    client: TestClient,
) -> None:
    headers = _register_and_login_profile(
        client,
        "9880000075",
        category="GENERAL",
        gender="OTHER",
    )

    result = _eligibility(client, headers, "Demo Community Growth Credit")

    assert result["eligible"] is False
    assert (
        "Applicant category does not match the scheme category"
        in result["reasons"]
    )


def test_female_only_scheme_accepts_female_and_rejects_male(
    client: TestClient,
) -> None:
    female_headers = _register_and_login_profile(
        client,
        "9880000076",
        category="GENERAL",
        gender="FEMALE",
    )
    male_headers = _register_and_login_profile(
        client,
        "9880000077",
        category="GENERAL",
        gender="MALE",
    )

    female = _eligibility(
        client,
        female_headers,
        "Demo Women Entrepreneur Starter",
    )
    male = _eligibility(
        client,
        male_headers,
        "Demo Women Entrepreneur Starter",
    )

    assert female["eligible"] is True
    assert male["eligible"] is False
    assert (
        "Applicant gender does not match the scheme gender requirement"
        in male["reasons"]
    )


def test_sc_female_scheme_requires_both_dimensions(
    client: TestClient,
) -> None:
    female_headers = _register_and_login_profile(
        client,
        "9880000078",
        category="SC",
        gender="FEMALE",
    )
    male_headers = _register_and_login_profile(
        client,
        "9880000079",
        category="SC",
        gender="MALE",
    )

    female = _eligibility(client, female_headers, "Demo Women Growth Capital")
    male = _eligibility(client, male_headers, "Demo Women Growth Capital")

    assert female["eligible"] is True
    assert male["eligible"] is False
    assert "Applicant category is eligible" in male["reasons"]
    assert (
        "Applicant gender does not match the scheme gender requirement"
        in male["reasons"]
    )


@pytest.mark.parametrize(
    ("phone", "category"),
    [
        ("9880000080", "SC"),
        ("9880000081", "ST"),
        ("9880000082", "OBC"),
        ("9880000083", "GENERAL"),
    ],
)
def test_any_category_scheme_accepts_all_categories(
    client: TestClient,
    phone: str,
    category: str,
) -> None:
    headers = _register_and_login_profile(
        client,
        phone,
        category=category,
        gender="OTHER",
    )

    result = _eligibility(
        client,
        headers,
        "Demo Inclusive Livelihood Support",
    )

    assert result["eligible"] is True


@pytest.mark.parametrize(
    ("phone", "gender"),
    [
        ("9880000084", "MALE"),
        ("9880000085", "FEMALE"),
        ("9880000086", "OTHER"),
    ],
)
def test_any_gender_scheme_accepts_all_supported_genders(
    client: TestClient,
    phone: str,
    gender: str,
) -> None:
    headers = _register_and_login_profile(
        client,
        phone,
        category="SC",
        gender=gender,
    )

    result = _eligibility(client, headers, "Demo Community Growth Credit")

    assert result["eligible"] is True


@pytest.mark.parametrize(
    ("phone", "invalid_category"),
    [
        ("9880000087", "Women"),
        ("9880000088", "Minority"),
    ],
)
def test_invalid_applicant_categories_are_rejected(
    client: TestClient,
    phone: str,
    invalid_category: str,
) -> None:
    payload = registration_payload(phone)
    payload["category"] = invalid_category

    response = client.post("/api/auth/register", json=payload)

    assert response.status_code == 422


def test_legacy_general_casing_compatible_and_omitted_gender_stays_null(
    client: TestClient,
) -> None:
    """Casing is still normalised, but gender is no longer defaulted.

    Multi-step registration made gender nullable: an unanswered gender must
    stay NULL rather than silently becoming OTHER, which is a real value
    that would affect gender-targeted scheme eligibility.
    """
    payload = registration_payload("9880000089")
    payload["category"] = "General"
    payload.pop("gender")

    response = client.post("/api/auth/register", json=payload)

    assert response.status_code == 201
    body = response.json()
    assert body["category"] == "GENERAL"
    assert body["gender"] is None
    assert body["profile_complete"] is False


def test_matching_applies_category_and_gender_together(
    client: TestClient,
) -> None:
    headers = _register_and_login_profile(
        client,
        "9880000090",
        category="GENERAL",
        gender="FEMALE",
    )

    response = client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": "100000.00", "tenure_months": 60},
    )

    assert response.status_code == 200
    names = {item["scheme"]["scheme_name"] for item in response.json()["candidates"]}
    assert "Demo Women Entrepreneur Starter" in names
    assert "Demo Inclusive Livelihood Support" in names
    assert "Demo Women Growth Capital" not in names


def test_seed_data_uses_only_valid_independent_dimensions(
    db_session: Session,
) -> None:
    # Restrict to seeded applicants (they carry no password hash). Users
    # registered by other tests share this session-scoped database, and one of
    # them deliberately omits gender to exercise incomplete profiles.
    users = list(
        db_session.scalars(select(User).where(User.password_hash.is_(None)))
    )
    schemes = list(db_session.scalars(select(Scheme)))
    categories = list(db_session.scalars(select(SchemeCategory)))

    assert {user.category for user in users} == {"SC", "ST", "OBC", "GENERAL"}
    assert {user.gender for user in users} == {"MALE", "FEMALE", "OTHER"}
    assert {item.category_name for item in categories} == {
        "ANY",
        "SC",
        "ST",
        "OBC",
        "GENERAL",
    }
    assert {scheme.gender_eligibility for scheme in schemes} <= {
        "ANY",
        "MALE",
        "FEMALE",
        "OTHER",
    }
    assert all(
        scheme.category.category_name not in {"WOMEN", "MINORITY"}
        for scheme in schemes
    )
