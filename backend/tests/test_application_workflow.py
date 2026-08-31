"""Tests for internal application lifecycle controls and absent public mutation."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.enums import ApplicationStatus
from app.models import Application
from app.services import application_workflow_service
from tests.helpers import register_and_login


def _create_application(
    client: TestClient,
    headers: dict[str, str],
) -> dict:
    scheme_id = client.get("/api/schemes").json()["items"][0]["id"]
    partner_id = client.get("/api/partners").json()[0]["id"]
    response = client.post(
        "/api/applications",
        headers=headers,
        json={
            "scheme_id": scheme_id,
            "partner_id": partner_id,
            "requested_amount": "100000.00",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_valid_status_transitions_are_persisted(
    client: TestClient,
    db_session: Session,
) -> None:
    _, headers = register_and_login(client, "9880000067")
    created = _create_application(client, headers)
    assert created["status"] == "submitted"
    application = db_session.get(Application, created["id"])
    assert application is not None

    application_workflow_service.transition_application(
        db_session,
        application,
        ApplicationStatus.UNDER_REVIEW,
    )
    assert application.status == ApplicationStatus.UNDER_REVIEW.value

    application_workflow_service.transition_application(
        db_session,
        application,
        ApplicationStatus.APPROVED,
    )
    application_workflow_service.transition_application(
        db_session,
        application,
        ApplicationStatus.COMPLETED,
    )
    assert application.status == ApplicationStatus.COMPLETED.value


def test_invalid_status_transition_is_rejected_without_mutation(
    client: TestClient,
    db_session: Session,
) -> None:
    _, headers = register_and_login(client, "9880000068")
    created = _create_application(client, headers)
    application = db_session.get(Application, created["id"])
    assert application is not None

    with pytest.raises(
        application_workflow_service.InvalidStatusTransitionError,
        match="Cannot transition application from submitted to approved",
    ):
        application_workflow_service.transition_application(
            db_session,
            application,
            ApplicationStatus.APPROVED,
        )

    assert application.status == ApplicationStatus.SUBMITTED.value


def test_normal_user_cannot_change_any_application_status(
    client: TestClient,
) -> None:
    _, owner_headers = register_and_login(client, "9880000069")
    _, other_headers = register_and_login(client, "9880000070")
    created = _create_application(client, owner_headers)

    own_attempt = client.patch(
        f"/api/applications/{created['id']}/status",
        headers=owner_headers,
        json={"status": "under_review"},
    )
    cross_user_attempt = client.patch(
        f"/api/applications/{created['id']}/status",
        headers=other_headers,
        json={"status": "under_review"},
    )
    unchanged = client.get(
        f"/api/applications/{created['id']}",
        headers=owner_headers,
    )

    assert own_attempt.status_code in {404, 405}
    assert cross_user_attempt.status_code in {404, 405}
    assert unchanged.status_code == 200
    assert unchanged.json()["status"] == "submitted"
