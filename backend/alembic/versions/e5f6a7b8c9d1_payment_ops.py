"""Payment refund / chargeback / triage columns."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e5f6a7b8c9d1"
down_revision = "e4f5a6b7c8d9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("payments", sa.Column("refund_reason", sa.Text(), nullable=True))
    op.add_column(
        "payments",
        sa.Column("refunded_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column("refunded_by_admin_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_payments_refunded_by_admin",
        "payments",
        "admin_users",
        ["refunded_by_admin_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.add_column("payments", sa.Column("chargeback_reason", sa.Text(), nullable=True))
    op.add_column(
        "payments",
        sa.Column("chargeback_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column("payments", sa.Column("triage_note", sa.Text(), nullable=True))
    op.add_column(
        "payments",
        sa.Column("failed_notified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_payments_provider", "payments", ["provider"])
    op.create_index("ix_payments_status", "payments", ["status"])


def downgrade() -> None:
    op.drop_index("ix_payments_status", table_name="payments")
    op.drop_index("ix_payments_provider", table_name="payments")
    op.drop_column("payments", "failed_notified_at")
    op.drop_column("payments", "triage_note")
    op.drop_column("payments", "chargeback_at")
    op.drop_column("payments", "chargeback_reason")
    op.drop_constraint("fk_payments_refunded_by_admin", "payments", type_="foreignkey")
    op.drop_column("payments", "refunded_by_admin_id")
    op.drop_column("payments", "refunded_at")
    op.drop_column("payments", "refund_reason")
