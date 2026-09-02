"""Separate applicant category from gender eligibility.

Revision ID: 20260903_0002
Revises: 20260829_0001
Create Date: 2026-09-03
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260903_0002"
down_revision: str | None = "20260829_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Normalize legacy values and add independent gender dimensions."""
    op.add_column(
        "users",
        sa.Column(
            "gender",
            sa.String(length=16),
            server_default=sa.text("'OTHER'"),
            nullable=True,
        ),
    )
    op.add_column(
        "schemes",
        sa.Column(
            "gender_eligibility",
            sa.String(length=16),
            server_default=sa.text("'ANY'"),
            nullable=True,
        ),
    )

    op.execute(
        sa.text(
            """
            INSERT INTO scheme_categories (category_name, description)
            SELECT
                'ANY',
                'Category-unrestricted scheme eligibility.'
            WHERE NOT EXISTS (
                SELECT 1
                FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'ANY'
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE users
            SET
                category = CASE phone
                    WHEN '9000000001' THEN 'SC'
                    WHEN '9000000002' THEN 'SC'
                    WHEN '9000000003' THEN 'SC'
                    WHEN '9000000004' THEN 'ST'
                    WHEN '9000000005' THEN 'ST'
                    WHEN '9000000006' THEN 'ST'
                    WHEN '9000000007' THEN 'OBC'
                    WHEN '9000000008' THEN 'OBC'
                    WHEN '9000000009' THEN 'OBC'
                    WHEN '9000000010' THEN 'GENERAL'
                    WHEN '9000000011' THEN 'GENERAL'
                    WHEN '9000000012' THEN 'GENERAL'
                    WHEN '9000000013' THEN 'GENERAL'
                    WHEN '9000000014' THEN 'SC'
                    WHEN '9000000015' THEN 'OBC'
                    WHEN '9000000016' THEN 'GENERAL'
                    WHEN '9000000017' THEN 'ST'
                    WHEN '9000000018' THEN 'OBC'
                    ELSE category
                END,
                gender = CASE phone
                    WHEN '9000000001' THEN 'FEMALE'
                    WHEN '9000000002' THEN 'MALE'
                    WHEN '9000000003' THEN 'OTHER'
                    WHEN '9000000004' THEN 'MALE'
                    WHEN '9000000005' THEN 'FEMALE'
                    WHEN '9000000006' THEN 'OTHER'
                    WHEN '9000000007' THEN 'MALE'
                    WHEN '9000000008' THEN 'FEMALE'
                    WHEN '9000000009' THEN 'OTHER'
                    WHEN '9000000010' THEN 'MALE'
                    WHEN '9000000011' THEN 'FEMALE'
                    WHEN '9000000012' THEN 'OTHER'
                    WHEN '9000000013' THEN 'FEMALE'
                    WHEN '9000000014' THEN 'FEMALE'
                    WHEN '9000000015' THEN 'FEMALE'
                    WHEN '9000000016' THEN 'MALE'
                    WHEN '9000000017' THEN 'FEMALE'
                    WHEN '9000000018' THEN 'OTHER'
                    ELSE gender
                END
            WHERE phone BETWEEN '9000000001' AND '9000000018'
            """
        )
    )

    # Preserve the meaning of legacy women-targeted schemes using gender.
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET
                category_id = (
                    SELECT id FROM scheme_categories
                    WHERE UPPER(TRIM(category_name)) = 'ANY'
                    ORDER BY id
                    LIMIT 1
                ),
                gender_eligibility = 'FEMALE'
            WHERE category_id IN (
                SELECT id FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) IN ('WOMEN', 'FEMALE')
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET category_id = (
                SELECT id FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'SC'
                ORDER BY id
                LIMIT 1
            )
            WHERE scheme_name = 'Demo Women Growth Capital'
            """
        )
    )

    # Minority is not a caste category in this domain. Convert those demo
    # records into explicitly unrestricted/general fictional schemes.
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET
                category_id = (
                    SELECT id FROM scheme_categories
                    WHERE UPPER(TRIM(category_name)) = 'ANY'
                    ORDER BY id
                    LIMIT 1
                ),
                gender_eligibility = 'ANY'
            WHERE category_id IN (
                SELECT id FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'MINORITY'
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET category_id = (
                SELECT id FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'GENERAL'
                ORDER BY id
                LIMIT 1
            )
            WHERE scheme_name = 'Demo Minority Enterprise Accelerator'
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET scheme_name = CASE scheme_name
                WHEN 'Demo Minority Livelihood Support'
                    THEN 'Demo Inclusive Livelihood Support'
                WHEN 'Demo Minority Enterprise Accelerator'
                    THEN 'Demo Inclusive Enterprise Accelerator'
                ELSE scheme_name
            END
            WHERE scheme_name IN (
                'Demo Minority Livelihood Support',
                'Demo Minority Enterprise Accelerator'
            )
            """
        )
    )

    # Gender can be recovered only for legacy users explicitly misclassified
    # as Women/Female. Other existing applicants use the compatibility default.
    op.execute(
        sa.text(
            """
            UPDATE users
            SET gender = CASE
                WHEN UPPER(TRIM(category)) IN ('WOMEN', 'FEMALE')
                    THEN 'FEMALE'
                ELSE 'OTHER'
            END
            WHERE phone NOT BETWEEN '9000000001' AND '9000000018'
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE users
            SET category = CASE UPPER(TRIM(category))
                WHEN 'SC' THEN 'SC'
                WHEN 'ST' THEN 'ST'
                WHEN 'OBC' THEN 'OBC'
                WHEN 'GENERAL' THEN 'GENERAL'
                ELSE 'GENERAL'
            END
            WHERE phone NOT BETWEEN '9000000001' AND '9000000018'
            """
        )
    )

    # Reuse one existing General row, normalizing its public representation.
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET category_id = (
                SELECT id
                FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'GENERAL'
                ORDER BY
                    CASE WHEN category_name = 'GENERAL' THEN 0 ELSE 1 END,
                    id
                LIMIT 1
            )
            WHERE category_id IN (
                SELECT id
                FROM scheme_categories
                WHERE UPPER(TRIM(category_name)) = 'GENERAL'
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            DELETE FROM scheme_categories
            WHERE UPPER(TRIM(category_name)) = 'GENERAL'
              AND id <> (
                  SELECT id
                  FROM scheme_categories
                  WHERE UPPER(TRIM(category_name)) = 'GENERAL'
                  ORDER BY
                      CASE WHEN category_name = 'GENERAL' THEN 0 ELSE 1 END,
                      id
                  LIMIT 1
              )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE scheme_categories
            SET category_name = 'GENERAL'
            WHERE UPPER(TRIM(category_name)) = 'GENERAL'
            """
        )
    )

    # Any remaining unsupported scheme group becomes category-unrestricted.
    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET category_id = (
                SELECT id FROM scheme_categories
                WHERE category_name = 'ANY'
                ORDER BY id
                LIMIT 1
            )
            WHERE category_id IN (
                SELECT id
                FROM scheme_categories
                WHERE UPPER(TRIM(category_name))
                    NOT IN ('ANY', 'SC', 'ST', 'OBC', 'GENERAL')
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            DELETE FROM scheme_categories
            WHERE UPPER(TRIM(category_name))
                NOT IN ('ANY', 'SC', 'ST', 'OBC', 'GENERAL')
            """
        )
    )

    op.alter_column(
        "users",
        "gender",
        existing_type=sa.String(length=16),
        nullable=False,
        server_default=sa.text("'OTHER'"),
    )
    op.alter_column(
        "schemes",
        "gender_eligibility",
        existing_type=sa.String(length=16),
        nullable=False,
        server_default=sa.text("'ANY'"),
    )

    op.create_check_constraint(
        "ck_users_category_values",
        "users",
        "category IN ('SC', 'ST', 'OBC', 'GENERAL')",
    )
    op.create_check_constraint(
        "ck_users_gender_values",
        "users",
        "gender IN ('MALE', 'FEMALE', 'OTHER')",
    )
    op.create_check_constraint(
        "ck_scheme_categories_name_values",
        "scheme_categories",
        "category_name IN ('ANY', 'SC', 'ST', 'OBC', 'GENERAL')",
    )
    op.create_check_constraint(
        "ck_schemes_gender_eligibility_values",
        "schemes",
        "gender_eligibility IN ('ANY', 'MALE', 'FEMALE', 'OTHER')",
    )
    op.create_index("ix_users_gender", "users", ["gender"], unique=False)
    op.create_index(
        "ix_schemes_gender_eligibility",
        "schemes",
        ["gender_eligibility"],
        unique=False,
    )


def downgrade() -> None:
    """Remove gender fields while retaining valid category data."""
    op.drop_index("ix_schemes_gender_eligibility", table_name="schemes")
    op.drop_index("ix_users_gender", table_name="users")
    op.drop_constraint(
        "ck_schemes_gender_eligibility_values",
        "schemes",
        type_="check",
    )
    op.drop_constraint(
        "ck_scheme_categories_name_values",
        "scheme_categories",
        type_="check",
    )
    op.drop_constraint("ck_users_gender_values", "users", type_="check")
    op.drop_constraint("ck_users_category_values", "users", type_="check")

    op.execute(
        sa.text(
            """
            UPDATE schemes
            SET category_id = (
                SELECT id FROM scheme_categories
                WHERE category_name = 'GENERAL'
                ORDER BY id
                LIMIT 1
            )
            WHERE category_id IN (
                SELECT id FROM scheme_categories WHERE category_name = 'ANY'
            )
            """
        )
    )
    op.execute(
        sa.text("DELETE FROM scheme_categories WHERE category_name = 'ANY'")
    )
    op.execute(
        sa.text(
            "UPDATE scheme_categories SET category_name = 'General' "
            "WHERE category_name = 'GENERAL'"
        )
    )
    op.drop_column("schemes", "gender_eligibility")
    op.drop_column("users", "gender")
