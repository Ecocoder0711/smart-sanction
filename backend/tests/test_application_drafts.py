"""Tests for saving an application as a draft before submitting it.

A draft is the applicant's own unsent work. It is the only status a client may
create besides submitted, the only one allowed to have no partner, and it must
never be mistaken for a submitted application.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.enums import ApplicationStatus
from app.models import Application
from app.schemas.application import CLIENT_CREATABLE_STATUSES
from app.services import application_workflow_service
from tests.helpers import register_and_login


def _ids(client: TestClient, headers: dict[str, str]) -> tuple[int, int]:
    """Return a real (scheme_id, partner_id) pair from the seeded data."""
    scheme_id = client.get("/api/schemes").json()["items"][0]["id"]
    partner_id = client.get(
        "/api/partners/routed",
        headers=headers,
    ).json()[0]["id"]
    return scheme_id, partner_id


def test_draft_without_partner_is_created(client: TestClient) -> None:
    """The point of a draft: save before deciding where to apply."""
    _, headers = register_and_login(client, "9880000601")
    scheme_id, _ = _ids(client, headers)

    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "requested_amount": "250000.00",
            "status": "draft",
        },
    )

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["status"] == "draft"
    assert body["partner_id"] is None
    assert body["partner_name"] is None
    assert body["scheme_name"]


def test_draft_with_partner_is_created(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000602")
    scheme_id, partner_id = _ids(client, headers)

    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": partner_id,
            "requested_amount": "250000.00",
            "status": "draft",
        },
    )

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "draft"
    assert response.json()["partner_id"] == partner_id


def test_submitted_without_partner_is_rejected(client: TestClient) -> None:
    """A submitted application must name somewhere to send it."""
    _, headers = register_and_login(client, "9880000603")
    scheme_id, _ = _ids(client, headers)

    explicit = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "requested_amount": "250000.00",
            "status": "submitted",
        },
    )
    # The default status is submitted, so omitting it must fail the same way.
    defaulted = client.post(
        "/api/applications",
        headers=headers,
        json={"scheme_id": scheme_id, "requested_amount": "250000.00"},
    )

    assert explicit.status_code == 422
    assert defaulted.status_code == 422
    assert "partner_id" in explicit.text


def test_existing_submitted_creation_is_unchanged(client: TestClient) -> None:
    """Backward compatibility: the pre-draft request body still works."""
    _, headers = register_and_login(client, "9880000604")
    scheme_id, partner_id = _ids(client, headers)

    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": partner_id,
            "requested_amount": "250000.00",
        },
    )

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "submitted"


@pytest.mark.parametrize(
    ("status", "phone"),
    [
        ("under_review", "9880000701"),
        ("approved", "9880000702"),
        ("rejected", "9880000703"),
        ("completed", "9880000704"),
    ],
)
def test_client_cannot_create_a_reviewed_status(
    client: TestClient,
    status: str,
    phone: str,
) -> None:
    """Review outcomes are reached through the workflow, never requested."""
    _, headers = register_and_login(client, phone)
    scheme_id, partner_id = _ids(client, headers)

    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": partner_id,
            "requested_amount": "250000.00",
            "status": status,
        },
    )

    assert response.status_code == 422, response.text


def test_only_draft_and_submitted_are_client_creatable() -> None:
    assert CLIENT_CREATABLE_STATUSES == (
        ApplicationStatus.DRAFT,
        ApplicationStatus.SUBMITTED,
    )


def test_status_draft_filter_returns_only_drafts(client: TestClient) -> None:
    _, headers = register_and_login(client, "9880000605")
    scheme_id, partner_id = _ids(client, headers)
    client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "requested_amount": "100000.00",
            "status": "draft",
        },
    )
    client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": partner_id,
            "requested_amount": "200000.00",
        },
    )

    drafts = client.get("/api/applications?status=draft", headers=headers).json()
    submitted = client.get(
        "/api/applications?status=submitted",
        headers=headers,
    ).json()
    everything = client.get("/api/applications", headers=headers).json()

    assert drafts["total"] == 1
    assert all(item["status"] == "draft" for item in drafts["items"])
    assert submitted["total"] == 1
    assert all(item["status"] == "submitted" for item in submitted["items"])
    # Partitioning the unfiltered list must reproduce the same split, which is
    # what the Dashboard relies on.
    assert everything["total"] == 2
    assert len([i for i in everything["items"] if i["status"] == "draft"]) == 1


def test_draft_belongs_only_to_its_owner(client: TestClient) -> None:
    _, owner_headers = register_and_login(client, "9880000606")
    scheme_id, _ = _ids(client, owner_headers)
    client.post(
        "/api/applications",
        headers=owner_headers,
        json={
            "scheme_id": scheme_id,
            "requested_amount": "250000.00",
            "status": "draft",
        },
    )
    _, other_headers = register_and_login(client, "9880000607")

    other_drafts = client.get(
        "/api/applications?status=draft",
        headers=other_headers,
    ).json()

    assert other_drafts["total"] == 0


def test_draft_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/applications",
        json={"scheme_id": 1, "requested_amount": "1000.00", "status": "draft"},
    )

    assert response.status_code == 401


def test_draft_with_unknown_partner_is_rejected(client: TestClient) -> None:
    """A named partner must exist, even on a draft."""
    _, headers = register_and_login(client, "9880000608")
    scheme_id, _ = _ids(client, headers)

    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": 999_999,
            "requested_amount": "250000.00",
            "status": "draft",
        },
    )

    assert response.status_code == 404


def test_draft_is_persisted_with_a_null_partner(
    client: TestClient,
    db_session: Session,
) -> None:
    """The row itself, not just the response, carries the draft state."""
    _, headers = register_and_login(client, "9880000609")
    scheme_id, _ = _ids(client, headers)
    created = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "requested_amount": "250000.00",
            "status": "draft",
        },
    ).json()

    stored = db_session.get(Application, created["id"])

    assert stored is not None
    assert stored.status == ApplicationStatus.DRAFT.value
    assert stored.partner_id is None


class TestWorkflow:
    """Draft joins the lifecycle without disturbing the existing transitions."""

    def test_draft_may_become_submitted(self) -> None:
        assert (
            ApplicationStatus.SUBMITTED
            in application_workflow_service.allowed_transitions(
                ApplicationStatus.DRAFT
            )
        )

    @pytest.mark.parametrize(
        "target",
        [
            ApplicationStatus.UNDER_REVIEW,
            ApplicationStatus.APPROVED,
            ApplicationStatus.REJECTED,
            ApplicationStatus.COMPLETED,
        ],
    )
    def test_draft_cannot_skip_ahead(self, target: ApplicationStatus) -> None:
        assert target not in application_workflow_service.allowed_transitions(
            ApplicationStatus.DRAFT
        )

    def test_nothing_transitions_back_into_draft(self) -> None:
        """A draft is only ever a starting point."""
        for status in ApplicationStatus:
            assert (
                ApplicationStatus.DRAFT
                not in application_workflow_service.allowed_transitions(status)
            )

    def test_existing_transitions_are_untouched(self) -> None:
        allowed = application_workflow_service.allowed_transitions
        assert allowed(ApplicationStatus.SUBMITTED) == frozenset(
            {ApplicationStatus.UNDER_REVIEW}
        )
        assert allowed(ApplicationStatus.UNDER_REVIEW) == frozenset(
            {ApplicationStatus.APPROVED, ApplicationStatus.REJECTED}
        )
        assert allowed(ApplicationStatus.APPROVED) == frozenset(
            {ApplicationStatus.COMPLETED}
        )
        assert allowed(ApplicationStatus.REJECTED) == frozenset()
        assert allowed(ApplicationStatus.COMPLETED) == frozenset()

    def test_no_public_submit_route_exists_yet(self, client: TestClient) -> None:
        """Submission is deliberately out of scope for this change."""
        paths = client.get("/openapi.json").json()["paths"]
        application_paths = {p for p in paths if "application" in p}

        assert not any("submit" in path for path in application_paths)
        assert application_paths == {
            "/api/applications",
            "/api/applications/{application_id}",
        }
