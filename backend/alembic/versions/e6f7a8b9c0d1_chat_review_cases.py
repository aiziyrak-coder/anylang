"""Chat review cases table for superadmin case management."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e6f7a8b9c0d1"
down_revision = "e5f6a7b8c9d1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_review_cases",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("reporter_user_id", sa.BigInteger(), nullable=True),
        sa.Column("reported_user_id", sa.BigInteger(), nullable=True),
        sa.Column("reason", sa.String(length=64), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("decision", sa.String(length=32), nullable=True),
        sa.Column("decision_note", sa.Text(), nullable=True),
        sa.Column("decided_by_admin_id", sa.Integer(), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("search_query", sa.String(length=255), nullable=True),
        sa.Column("created_by_admin_id", sa.Integer(), nullable=True),
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
        sa.ForeignKeyConstraint(["chat_id"], ["chats.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reported_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["decided_by_admin_id"], ["admin_users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_admin_id"], ["admin_users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_review_cases_chat_id", "chat_review_cases", ["chat_id"])
    op.create_index("ix_chat_review_cases_status", "chat_review_cases", ["status"])
    op.create_index(
        "ix_chat_review_cases_reporter_user_id", "chat_review_cases", ["reporter_user_id"]
    )
    op.create_index(
        "ix_chat_review_cases_reported_user_id", "chat_review_cases", ["reported_user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_chat_review_cases_reported_user_id", table_name="chat_review_cases")
    op.drop_index("ix_chat_review_cases_reporter_user_id", table_name="chat_review_cases")
    op.drop_index("ix_chat_review_cases_status", table_name="chat_review_cases")
    op.drop_index("ix_chat_review_cases_chat_id", table_name="chat_review_cases")
    op.drop_table("chat_review_cases")
