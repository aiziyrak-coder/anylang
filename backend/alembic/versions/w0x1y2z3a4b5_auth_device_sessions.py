"""Active auth sessions: device metadata on refresh_tokens."""

from alembic import op
import sqlalchemy as sa

revision = "w0x1y2z3a4b5_auth_device_sessions"
down_revision = "v9w0x1y2z3a4_business_bio"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "refresh_tokens",
        sa.Column("device_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("device_name", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("device_type", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("platform", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("app_version", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("ip_address", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("session_started_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_refresh_tokens_device_id",
        "refresh_tokens",
        ["device_id"],
    )
    # Eski qatorlar: session_started_at = created_at
    op.execute(
        "UPDATE refresh_tokens SET session_started_at = created_at "
        "WHERE session_started_at IS NULL"
    )
    op.execute(
        "UPDATE refresh_tokens SET last_active_at = COALESCE(updated_at, created_at) "
        "WHERE last_active_at IS NULL"
    )


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_device_id", table_name="refresh_tokens")
    op.drop_column("refresh_tokens", "session_started_at")
    op.drop_column("refresh_tokens", "last_active_at")
    op.drop_column("refresh_tokens", "ip_address")
    op.drop_column("refresh_tokens", "app_version")
    op.drop_column("refresh_tokens", "platform")
    op.drop_column("refresh_tokens", "device_type")
    op.drop_column("refresh_tokens", "device_name")
    op.drop_column("refresh_tokens", "device_id")
