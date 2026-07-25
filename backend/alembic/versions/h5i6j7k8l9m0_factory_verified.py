"""Factory Verified fields on business profiles."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "h5i6j7k8l9m0"
down_revision = "g4h5i6j7k8l9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column(
            "factory_verified",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "inspection_passed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column("audit_report_url", sa.String(length=512), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "audit_report_url")
    op.drop_column("business_profiles", "inspection_passed")
    op.drop_column("business_profiles", "factory_verified")
