"""Product multilingual catalog fields.

Revision ID: x2y3z4a5b6c7
Revises: w1x2y3z4a5b6
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "x2y3z4a5b6c7"
down_revision = "w1x2y3z4a5b6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column(
            "name_i18n",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.add_column(
        "products",
        sa.Column(
            "short_description_i18n",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.add_column(
        "products",
        sa.Column(
            "description_i18n",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.add_column(
        "products",
        sa.Column("source_lang", sa.String(length=8), nullable=True),
    )
    op.add_column(
        "partner_applications",
        sa.Column("source_lang", sa.String(length=8), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("partner_applications", "source_lang")
    op.drop_column("products", "source_lang")
    op.drop_column("products", "description_i18n")
    op.drop_column("products", "short_description_i18n")
    op.drop_column("products", "name_i18n")
