"""Partner applications table.

Revision ID: w1x2y3z4a5b6
Revises: v0w1x2y3z4a5
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "w1x2y3z4a5b6"
down_revision = "v0w1x2y3z4a5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "partner_applications",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="pending"),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("contact_name", sa.String(length=100), nullable=False),
        sa.Column("phone", sa.String(length=40), nullable=True),
        sa.Column("company_name", sa.String(length=200), nullable=False),
        sa.Column("country", sa.String(length=2), nullable=True),
        sa.Column("business_role", sa.String(length=32), nullable=True),
        sa.Column("website", sa.String(length=255), nullable=True),
        sa.Column("bio", sa.String(length=300), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("founded_year", sa.Integer(), nullable=True),
        sa.Column("moq", sa.String(length=120), nullable=True),
        sa.Column("production_capacity", sa.String(length=160), nullable=True),
        sa.Column("lead_time", sa.String(length=120), nullable=True),
        sa.Column(
            "certificates",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "export_countries",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "payment_methods",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "incoterms",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column("logo_url", sa.String(length=512), nullable=True),
        sa.Column(
            "factory_image_urls",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column("factory_video_url", sa.String(length=512), nullable=True),
        sa.Column("admin_note", sa.String(length=500), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_by", sa.Integer(), nullable=True),
        sa.Column("created_user_id", sa.BigInteger(), nullable=True),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_partner_applications_status", "partner_applications", ["status"])
    op.create_index("ix_partner_applications_email", "partner_applications", ["email"])
    op.create_index(
        "ix_partner_applications_submitted_at", "partner_applications", ["submitted_at"]
    )
    op.create_index(
        "ix_partner_applications_created_user_id",
        "partner_applications",
        ["created_user_id"],
    )

    op.create_table(
        "partner_application_products",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("application_id", sa.BigInteger(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column(
            "short_description", sa.String(length=120), nullable=False, server_default=""
        ),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("price", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(length=8), nullable=False, server_default="USD"),
        sa.Column("category", sa.String(length=64), nullable=False, server_default="other"),
        sa.Column("moq", sa.String(length=120), nullable=True),
        sa.Column("shipping_info", sa.String(length=255), nullable=True),
        sa.Column(
            "image_urls",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column("video_url", sa.String(length=512), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["application_id"], ["partner_applications.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_partner_application_products_application_id",
        "partner_application_products",
        ["application_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_partner_application_products_application_id",
        table_name="partner_application_products",
    )
    op.drop_table("partner_application_products")
    op.drop_index("ix_partner_applications_created_user_id", table_name="partner_applications")
    op.drop_index("ix_partner_applications_submitted_at", table_name="partner_applications")
    op.drop_index("ix_partner_applications_email", table_name="partner_applications")
    op.drop_index("ix_partner_applications_status", table_name="partner_applications")
    op.drop_table("partner_applications")
