"""add soft delete restore and admin audit

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-07-21 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("deletion_reason", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("scheduled_purge_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_users_deleted_at", "users", ["deleted_at"])
    op.create_index("ix_users_scheduled_purge_at", "users", ["scheduled_purge_at"])

    op.create_index("ix_subscriptions_plan_active", "subscriptions", ["plan", "is_active"])
    op.create_index("ix_payments_status_paid_at", "payments", ["status", "paid_at"])
    op.create_index("ix_messages_chat_created", "messages", ["chat_id", "created_at"])

    op.create_table(
        "admin_audit_logs",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("actor_admin_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("target_type", sa.String(length=64), nullable=True),
        sa.Column("target_id", sa.String(length=64), nullable=True),
        sa.Column("meta", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("ip", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["actor_admin_id"], ["admin_users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_audit_logs_actor_admin_id", "admin_audit_logs", ["actor_admin_id"])
    op.create_index("ix_admin_audit_logs_action", "admin_audit_logs", ["action"])
    op.create_index("ix_admin_audit_logs_target_type", "admin_audit_logs", ["target_type"])
    op.create_index("ix_admin_audit_logs_target_id", "admin_audit_logs", ["target_id"])

    op.create_table(
        "account_restore_requests",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("number", sa.String(length=7), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="pending"),
        sa.Column("decided_by_admin_id", sa.Integer(), nullable=True),
        sa.Column("decision_note", sa.Text(), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["decided_by_admin_id"], ["admin_users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_account_restore_requests_user_id", "account_restore_requests", ["user_id"])
    op.create_index("ix_account_restore_requests_email", "account_restore_requests", ["email"])
    op.create_index("ix_account_restore_requests_status", "account_restore_requests", ["status"])


def downgrade() -> None:
    op.drop_table("account_restore_requests")
    op.drop_table("admin_audit_logs")
    op.drop_index("ix_messages_chat_created", table_name="messages")
    op.drop_index("ix_payments_status_paid_at", table_name="payments")
    op.drop_index("ix_subscriptions_plan_active", table_name="subscriptions")
    op.drop_index("ix_users_scheduled_purge_at", table_name="users")
    op.drop_index("ix_users_deleted_at", table_name="users")
    op.drop_column("users", "scheduled_purge_at")
    op.drop_column("users", "deletion_reason")
    op.drop_column("users", "deleted_at")
