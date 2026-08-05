"""Restore queue: identity checklist, risk, partial restore, SLA, must_change_password."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "e7f8a9b0c1d2"
down_revision = "e6f7a8b9c0d1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "must_change_password",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )

    op.add_column(
        "account_restore_requests",
        sa.Column(
            "email_otp_verified",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "number_verified",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "device_verified",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column("claimed_device_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column("claimed_device_name", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "risk_impersonation",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column("risk_notes", sa.Text(), nullable=True),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "keep_chats",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "sla_hours",
            sa.Integer(),
            server_default="24",
            nullable=False,
        ),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column("last_status_notified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "account_restore_requests",
        sa.Column(
            "identity_meta",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("account_restore_requests", "identity_meta")
    op.drop_column("account_restore_requests", "last_status_notified_at")
    op.drop_column("account_restore_requests", "sla_hours")
    op.drop_column("account_restore_requests", "keep_chats")
    op.drop_column("account_restore_requests", "risk_notes")
    op.drop_column("account_restore_requests", "risk_impersonation")
    op.drop_column("account_restore_requests", "claimed_device_name")
    op.drop_column("account_restore_requests", "claimed_device_id")
    op.drop_column("account_restore_requests", "device_verified")
    op.drop_column("account_restore_requests", "number_verified")
    op.drop_column("account_restore_requests", "email_otp_verified")
    op.drop_column("users", "must_change_password")
