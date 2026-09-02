"""Allow applicants to register before completing their profile.

Makes annual_income, category, and gender nullable so registration can
succeed with name/phone/password alone. No placeholder value is written:
a missing field stays NULL, and eligibility/matching refuse to run until
the applicant supplies it through PUT /api/users/me.

The existing CHECK constraints need no change. A CHECK passes unless it
evaluates to false, and `NULL IN (...)` evaluates to NULL, so NULL rows
satisfy them while any supplied value is still restricted to the enum.

Revision ID: 20260904_0004
Revises: 20260903_0003
Create Date: 2026-09-04
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260904_0004"
down_revision: str | None = "20260903_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OPTIONAL_PROFILE_COLUMNS: tuple[tuple[str, sa.types.TypeEngine], ...] = (
    ("annual_income", sa.Numeric(precision=14, scale=2)),
    ("category", sa.String(length=50)),
    ("gender", sa.String(length=16)),
)


def upgrade() -> None:
    """Drop NOT NULL from the deferred profile columns.

    Safe on a populated database: existing rows keep their values and no
    row is rewritten.
    """
    for column_name, column_type in _OPTIONAL_PROFILE_COLUMNS:
        op.alter_column(
            "users",
            column_name,
            existing_type=column_type,
            nullable=True,
        )
    # gender previously defaulted to 'OTHER'; drop it so an unanswered
    # gender stays NULL instead of silently becoming a real enum value
    # that would affect scheme eligibility.
    op.alter_column("users", "gender", existing_type=sa.String(length=16), server_default=None)


def downgrade() -> None:
    """Restore NOT NULL, refusing to run if that would need invented data.

    There is no correct value to backfill an unanswered income, category,
    or gender with, and guessing would corrupt eligibility and ML results.
    So this fails loudly instead.
    """
    connection = op.get_bind()
    blocking: list[str] = []
    for column_name, _ in _OPTIONAL_PROFILE_COLUMNS:
        null_count = connection.execute(
            sa.text(f"SELECT COUNT(*) FROM users WHERE {column_name} IS NULL")  # noqa: S608
        ).scalar_one()
        if null_count:
            blocking.append(f"{column_name} ({null_count} row(s))")

    if blocking:
        raise RuntimeError(
            "Cannot restore NOT NULL while incomplete profiles exist: "
            + ", ".join(blocking)
            + ". Complete or remove those users first; this migration will "
            "not invent placeholder values."
        )

    op.alter_column(
        "users",
        "gender",
        existing_type=sa.String(length=16),
        server_default="OTHER",
    )
    for column_name, column_type in _OPTIONAL_PROFILE_COLUMNS:
        op.alter_column(
            "users",
            column_name,
            existing_type=column_type,
            nullable=False,
        )
