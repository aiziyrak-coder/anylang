"""Business verification requests — admin review queue."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "u8v9w0x1y2z3_business_verification"
down_revision = "t7u8v9w0x1y2_support_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "business_verification_requests",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("business_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=16),
            server_default="draft",
            nullable=False,
        ),
        sa.Column("note", sa.String(length=500), nullable=True),
        sa.Column("admin_note", sa.String(length=500), nullable=True),
        sa.Column("reviewed_by_admin_id", sa.BigInteger(), nullable=True),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["business_id"], ["business_profiles.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by_admin_id"], ["admin_users.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_biz_verif_req_user_id",
        "business_verification_requests",
        ["user_id"],
    )
    op.create_index(
        "ix_biz_verif_req_status",
        "business_verification_requests",
        ["status"],
    )
    op.create_index(
        "ix_biz_verif_req_user_status",
        "business_verification_requests",
        ["user_id", "status"],
    )

    op.create_table(
        "business_verification_documents",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("request_id", sa.BigInteger(), nullable=False),
        sa.Column("doc_type", sa.String(length=40), nullable=False),
        sa.Column("url", sa.String(length=512), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=True),
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
            ["request_id"],
            ["business_verification_requests.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_biz_verif_docs_request_id",
        "business_verification_documents",
        ["request_id"],
    )
    op.create_index(
        "ix_biz_verif_docs_request_type",
        "business_verification_documents",
        ["request_id", "doc_type"],
    )

    # Keep JSONB unused marker for future; no schema change on business_profiles.


def downgrade() -> None:
    op.drop_index(
        "ix_biz_verif_docs_request_type",
        table_name="business_verification_documents",
    )
    op.drop_index(
        "ix_biz_verif_docs_request_id",
        table_name="business_verification_documents",
    )
    op.drop_table("business_verification_documents")
    op.drop_index(
        "ix_biz_verif_req_user_status",
        table_name="business_verification_requests",
    )
    op.drop_index(
        "ix_biz_verif_req_status",
        table_name="business_verification_requests",
    )
    op.drop_index(
        "ix_biz_verif_req_user_id",
        table_name="business_verification_requests",
    )
    op.drop_table("business_verification_requests")
