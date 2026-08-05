"""Plan catalog overrides + subscription policy for admin."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "d3e4f5a6b7c8"
down_revision = "c2d3e4f5a6b7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "plan_catalog_overrides",
        sa.Column("plan_code", sa.String(length=32), nullable=False),
        sa.Column("monthly_usd", sa.Numeric(10, 2), nullable=True),
        sa.Column("trial_days", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "limits",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "region_currency",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{\"default\": \"USD\"}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "features_override",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("plan_code"),
    )
    op.create_table(
        "subscription_policies",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("grace_days", sa.Integer(), server_default="3", nullable=False),
        sa.Column(
            "soft_lock_enabled",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "reminder_days",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[7, 3, 1]'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "churn_reasons",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text(
                "'[\"too_expensive\", \"not_using\", \"switched_plan\", "
                "\"missing_features\", \"other\"]'::jsonb"
            ),
            nullable=False,
        ),
        sa.Column(
            "soft_lock_message",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text(
                "'{\"uz\": \"Obuna muddati tugadi — grace davri\", "
                "\"ru\": \"Подписка истекла — льготный период\", "
                "\"en\": \"Subscription expired — grace period\"}'::jsonb"
            ),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute(
        """
        INSERT INTO subscription_policies (id) VALUES (1)
        ON CONFLICT (id) DO NOTHING
        """
    )
    for code, price in (("premium", "5.00"), ("business", "15.00"), ("basic", None)):
        if price is None:
            op.execute(
                """
                INSERT INTO plan_catalog_overrides (plan_code, monthly_usd, trial_days, limits)
                VALUES ('basic', NULL, 0, '{"translations_per_day": 20}'::jsonb)
                ON CONFLICT (plan_code) DO NOTHING
                """
            )
        else:
            limits = (
                '{"translations_per_day": null, "live_mode": true}'
                if code == "premium"
                else '{"translations_per_day": null, "ai_tools": true, "storage_gb": 100}'
            )
            op.execute(
                f"""
                INSERT INTO plan_catalog_overrides (plan_code, monthly_usd, trial_days, limits)
                VALUES ('{code}', {price}, 7, '{limits}'::jsonb)
                ON CONFLICT (plan_code) DO NOTHING
                """
            )


def downgrade() -> None:
    op.drop_table("subscription_policies")
    op.drop_table("plan_catalog_overrides")
