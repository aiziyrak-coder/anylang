"""Audit journal: before/after diff, content hash, anomaly alerts."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "e8f9a0b1c2d3"
down_revision = "e7f8a9b0c1d2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "admin_audit_logs",
        sa.Column(
            "before_state",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "admin_audit_logs",
        sa.Column(
            "after_state",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "admin_audit_logs",
        sa.Column("content_hash", sa.String(length=64), nullable=True),
    )
    op.create_index(
        "ix_admin_audit_logs_created_at",
        "admin_audit_logs",
        ["created_at"],
    )
    op.create_index(
        "ix_admin_audit_logs_ip",
        "admin_audit_logs",
        ["ip"],
    )

    # Immutability: block UPDATE/DELETE on audit rows (append-only).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION admin_audit_logs_immutable()
        RETURNS trigger AS $$
        BEGIN
          RAISE EXCEPTION 'admin_audit_logs is immutable';
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_admin_audit_logs_immutable
        BEFORE UPDATE OR DELETE ON admin_audit_logs
        FOR EACH ROW EXECUTE PROCEDURE admin_audit_logs_immutable();
        """
    )

    op.create_table(
        "admin_activity_alerts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("alert_type", sa.String(length=64), nullable=False),
        sa.Column("severity", sa.String(length=16), nullable=False, server_default="medium"),
        sa.Column("actor_admin_id", sa.Integer(), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column(
            "detail",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "sample_log_ids",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "status",
            sa.String(length=16),
            nullable=False,
            server_default="open",
        ),
        sa.Column("acked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("acked_by_admin_id", sa.Integer(), nullable=True),
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
            ["actor_admin_id"], ["admin_users.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["acked_by_admin_id"], ["admin_users.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_admin_activity_alerts_status",
        "admin_activity_alerts",
        ["status"],
    )
    op.create_index(
        "ix_admin_activity_alerts_created_at",
        "admin_activity_alerts",
        ["created_at"],
    )
    op.create_index(
        "ix_admin_activity_alerts_actor",
        "admin_activity_alerts",
        ["actor_admin_id"],
    )


def downgrade() -> None:
    op.drop_table("admin_activity_alerts")
    op.execute("DROP TRIGGER IF EXISTS trg_admin_audit_logs_immutable ON admin_audit_logs")
    op.execute("DROP FUNCTION IF EXISTS admin_audit_logs_immutable()")
    op.drop_index("ix_admin_audit_logs_ip", table_name="admin_audit_logs")
    op.drop_index("ix_admin_audit_logs_created_at", table_name="admin_audit_logs")
    op.drop_column("admin_audit_logs", "content_hash")
    op.drop_column("admin_audit_logs", "after_state")
    op.drop_column("admin_audit_logs", "before_state")
