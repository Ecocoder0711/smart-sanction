"""Let applicants save an application as a draft before submitting it.

Three changes, all additive in effect:

* the status CHECK gains 'draft', so a draft row can exist at all;
* partner_id becomes nullable, so a draft can be saved before the applicant
  has chosen where to apply;
* a new CHECK holds every non-draft row to a partner, so relaxing NOT NULL
  cannot let a submitted application escape without one.

Existing rows are unaffected: every current application is already non-draft
with a partner set, which both new constraints accept.

Revision ID: 20260905_0005
Revises: 20260904_0004
Create Date: 2026-09-05
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260905_0005"
down_revision: str | None = "20260904_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_STATUS_CONSTRAINT = "ck_applications_status_values"
_PARTNER_CONSTRAINT = "ck_applications_submitted_requires_partner"

_STATUSES_WITH_DRAFT = (
    "'draft', 'submitted', 'under_review', 'approved', 'rejected', 'completed'"
)
_STATUSES_WITHOUT_DRAFT = (
    "'submitted', 'under_review', 'approved', 'rejected', 'completed'"
)


def upgrade() -> None:
    """Admit draft applications and allow them to have no partner yet."""
    op.drop_constraint(_STATUS_CONSTRAINT, "applications", type_="check")
    op.create_check_constraint(
        _STATUS_CONSTRAINT,
        "applications",
        f"status IN ({_STATUSES_WITH_DRAFT})",
    )

    op.alter_column(
        "applications",
        "partner_id",
        existing_type=sa.Integer(),
        nullable=True,
    )

    # Added after the column is relaxed, so the database itself refuses a
    # submitted application with nowhere to send it.
    op.create_check_constraint(
        _PARTNER_CONSTRAINT,
        "applications",
        "status = 'draft' OR partner_id IS NOT NULL",
    )


def downgrade() -> None:
    """Reverse the change, refusing to run if that would destroy real rows.

    Restoring NOT NULL on partner_id and dropping 'draft' from the status
    CHECK would orphan any draft that exists. There is no correct partner to
    invent for one, and silently deleting an applicant's saved work would be
    worse, so this fails loudly and names what is in the way.
    """
    connection = op.get_bind()

    draft_count = connection.execute(
        sa.text("SELECT COUNT(*) FROM applications WHERE status = 'draft'")
    ).scalar_one()
    null_partner_count = connection.execute(
        sa.text("SELECT COUNT(*) FROM applications WHERE partner_id IS NULL")
    ).scalar_one()

    blocking: list[str] = []
    if draft_count:
        blocking.append(f"{draft_count} draft application(s)")
    if null_partner_count:
        blocking.append(f"{null_partner_count} application(s) with no partner")

    if blocking:
        raise RuntimeError(
            "Cannot downgrade while drafts exist: "
            + ", ".join(blocking)
            + ". Submit or delete them first; this migration will not discard "
            "saved applications or invent a partner for them."
        )

    op.drop_constraint(_PARTNER_CONSTRAINT, "applications", type_="check")
    op.alter_column(
        "applications",
        "partner_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.drop_constraint(_STATUS_CONSTRAINT, "applications", type_="check")
    op.create_check_constraint(
        _STATUS_CONSTRAINT,
        "applications",
        f"status IN ({_STATUSES_WITHOUT_DRAFT})",
    )
