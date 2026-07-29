"""User.extra_account_slots — multi-account extras on one device."""

from alembic import op
import sqlalchemy as sa

revision = "x1y2z3a4b5c6_extra_account_slots"
down_revision = "w0x1y2z3a4b5_auth_device_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "extra_account_slots",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "extra_account_slots")
