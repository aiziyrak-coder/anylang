"""Admin console production hardening indexes.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-07-21
"""

from __future__ import annotations

from alembic import op

revision = "c3d4e5f6a7b8"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_restore_pending_email
        ON account_restore_requests (email)
        WHERE status = 'pending'
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_users_purge_queue
        ON users (scheduled_purge_at)
        WHERE deleted_at IS NOT NULL AND deletion_reason IS DISTINCT FROM 'purged'
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_admin_audit_logs_created_at
        ON admin_audit_logs (created_at DESC)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_admin_audit_logs_created_at")
    op.execute("DROP INDEX IF EXISTS ix_users_purge_queue")
    op.execute("DROP INDEX IF EXISTS uq_restore_pending_email")
