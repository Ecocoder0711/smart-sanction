"""Add state and district to applicant profiles.

Revision ID: 20260903_0003
Revises: 20260903_0002
Create Date: 2026-09-03
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260903_0003"
down_revision: str | None = "20260903_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add optional administrative-location fields to users."""
    op.add_column(
        "users",
        sa.Column("state", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("district", sa.String(length=100), nullable=True),
    )


def downgrade() -> None:
    """Remove optional administrative-location fields from users."""
    op.drop_column("users", "district")
    op.drop_column("users", "state")
