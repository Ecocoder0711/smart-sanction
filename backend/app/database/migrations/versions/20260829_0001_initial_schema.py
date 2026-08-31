"""Create the initial SMART-SANCTION database schema.

Revision ID: 20260829_0001
Revises:
Create Date: 2026-08-29
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

# Revision identifiers, used by Alembic.
revision: str = "20260829_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create all Phase 2 tables, constraints, and indexes."""
    op.create_table(
        "scheme_categories",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("category_name", sa.String(length=50), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_scheme_categories"),
        sa.UniqueConstraint(
            "category_name",
            name="uq_scheme_categories_category_name",
        ),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("full_name", sa.String(length=150), nullable=False),
        sa.Column("phone", sa.String(length=15), nullable=False),
        sa.Column("annual_income", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("category", sa.String(length=50), nullable=False),
        sa.Column("latitude", sa.Numeric(precision=9, scale=6), nullable=True),
        sa.Column("longitude", sa.Numeric(precision=9, scale=6), nullable=True),
        sa.Column("password_hash", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "annual_income >= 0",
            name="ck_users_annual_income_non_negative",
        ),
        sa.CheckConstraint(
            "latitude IS NULL OR latitude BETWEEN -90 AND 90",
            name="ck_users_latitude_range",
        ),
        sa.CheckConstraint(
            "longitude IS NULL OR longitude BETWEEN -180 AND 180",
            name="ck_users_longitude_range",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("phone", name="uq_users_phone"),
    )
    op.create_index("ix_users_category", "users", ["category"], unique=False)

    op.create_table(
        "schemes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("scheme_name", sa.String(length=200), nullable=False),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.Column("max_loan_limit", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("interest_rate", sa.Numeric(precision=7, scale=4), nullable=False),
        sa.Column("moratorium_months", sa.Integer(), nullable=False),
        sa.Column("max_income_limit", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "interest_rate >= 0",
            name="ck_schemes_interest_rate_non_negative",
        ),
        sa.CheckConstraint(
            "max_income_limit >= 0",
            name="ck_schemes_max_income_non_negative",
        ),
        sa.CheckConstraint(
            "max_loan_limit >= 0",
            name="ck_schemes_max_loan_non_negative",
        ),
        sa.CheckConstraint(
            "moratorium_months >= 0",
            name="ck_schemes_moratorium_non_negative",
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["scheme_categories.id"],
            name="fk_schemes_category_id_scheme_categories",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_schemes"),
    )
    op.create_index(
        "ix_schemes_category_id",
        "schemes",
        ["category_id"],
        unique=False,
    )
    op.create_index(
        "ix_schemes_is_active",
        "schemes",
        ["is_active"],
        unique=False,
    )

    op.create_table(
        "channel_partners",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("bank_name", sa.String(length=150), nullable=False),
        sa.Column("branch_code", sa.String(length=50), nullable=False),
        sa.Column("latitude", sa.Numeric(precision=9, scale=6), nullable=False),
        sa.Column("longitude", sa.Numeric(precision=9, scale=6), nullable=False),
        sa.Column("npa_percentage", sa.Numeric(precision=7, scale=4), nullable=False),
        sa.Column("quota_remaining", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "latitude BETWEEN -90 AND 90",
            name="ck_partners_latitude_range",
        ),
        sa.CheckConstraint(
            "longitude BETWEEN -180 AND 180",
            name="ck_partners_longitude_range",
        ),
        sa.CheckConstraint(
            "npa_percentage BETWEEN 0 AND 100",
            name="ck_partners_npa_percentage_range",
        ),
        sa.CheckConstraint(
            "quota_remaining >= 0",
            name="ck_partners_quota_non_negative",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_channel_partners"),
    )
    op.create_index(
        "ix_channel_partners_is_active",
        "channel_partners",
        ["is_active"],
        unique=False,
    )

    op.create_table(
        "applications",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("scheme_id", sa.Integer(), nullable=False),
        sa.Column("partner_id", sa.Integer(), nullable=False),
        sa.Column("requested_amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("ml_match_score", sa.Numeric(precision=6, scale=5), nullable=True),
        sa.Column(
            "ml_approval_probability",
            sa.Numeric(precision=6, scale=5),
            nullable=True,
        ),
        sa.Column(
            "application_date",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(length=32),
            server_default=sa.text("'submitted'"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "ml_approval_probability IS NULL OR ml_approval_probability BETWEEN 0 AND 1",
            name="ck_applications_ml_approval_probability_range",
        ),
        sa.CheckConstraint(
            "ml_match_score IS NULL OR ml_match_score BETWEEN 0 AND 1",
            name="ck_applications_ml_match_score_range",
        ),
        sa.CheckConstraint(
            "requested_amount > 0",
            name="ck_applications_requested_amount_positive",
        ),
        sa.CheckConstraint(
            "status IN ('submitted', 'under_review', 'approved', 'rejected', 'completed')",
            name="ck_applications_status_values",
        ),
        sa.ForeignKeyConstraint(
            ["partner_id"],
            ["channel_partners.id"],
            name="fk_applications_partner_id_channel_partners",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["scheme_id"],
            ["schemes.id"],
            name="fk_applications_scheme_id_schemes",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_applications_user_id_users",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_applications"),
    )
    op.create_index(
        "ix_applications_partner_id",
        "applications",
        ["partner_id"],
        unique=False,
    )
    op.create_index(
        "ix_applications_scheme_id",
        "applications",
        ["scheme_id"],
        unique=False,
    )
    op.create_index(
        "ix_applications_status",
        "applications",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_applications_user_id",
        "applications",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    """Drop all Phase 2 objects in reverse dependency order."""
    op.drop_index("ix_applications_user_id", table_name="applications")
    op.drop_index("ix_applications_status", table_name="applications")
    op.drop_index("ix_applications_scheme_id", table_name="applications")
    op.drop_index("ix_applications_partner_id", table_name="applications")
    op.drop_table("applications")

    op.drop_index("ix_channel_partners_is_active", table_name="channel_partners")
    op.drop_table("channel_partners")

    op.drop_index("ix_schemes_is_active", table_name="schemes")
    op.drop_index("ix_schemes_category_id", table_name="schemes")
    op.drop_table("schemes")

    op.drop_index("ix_users_category", table_name="users")
    op.drop_table("users")

    op.drop_table("scheme_categories")

