"""Delete seeded partner users (partner.m*@partners.anylang.uz) and their products."""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select, text

from app.db.session import get_session_factory
from app.models.user import User


async def run(*, dry_run: bool) -> None:
    factory = get_session_factory()
    async with factory() as db:
        users = (
            await db.execute(
                select(User).where(User.email.like("partner.m%@partners.anylang.uz"))
            )
        ).scalars().all()
        ids = [u.id for u in users]
        print(f"partner users found: {len(ids)}")
        if not ids:
            return

        pc = (
            await db.execute(
                text("select count(1) from products where seller_id = any(:ids)"),
                {"ids": ids},
            )
        ).scalar()
        print(f"their products: {pc}")

        if dry_run:
            print("dry-run — nothing deleted")
            for u in users[:5]:
                print(f"  would delete {u.id} {u.email}")
            if len(users) > 5:
                print(f"  ... +{len(users) - 5}")
            return

        await db.execute(
            text(
                "delete from product_images where product_id in "
                "(select id from products where seller_id = any(:ids))"
            ),
            {"ids": ids},
        )
        # Favorites / views / top requests may reference products
        await db.execute(
            text(
                "delete from product_favorites where product_id in "
                "(select id from products where seller_id = any(:ids))"
            ),
            {"ids": ids},
        )
        await db.execute(
            text(
                "delete from product_views where product_id in "
                "(select id from products where seller_id = any(:ids))"
            ),
            {"ids": ids},
        )
        await db.execute(
            text(
                "delete from product_top_requests where product_id in "
                "(select id from products where seller_id = any(:ids))"
            ),
            {"ids": ids},
        )
        await db.execute(
            text("delete from products where seller_id = any(:ids)"),
            {"ids": ids},
        )
        await db.execute(
            text("delete from users where id = any(:ids)"),
            {"ids": ids},
        )
        await db.commit()
        left = (
            await db.execute(
                text(
                    "select count(1) from users "
                    "where email like 'partner.m%@partners.anylang.uz'"
                )
            )
        ).scalar()
        print(f"deleted. remaining partner users: {left}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    asyncio.run(run(dry_run=args.dry_run))


if __name__ == "__main__":
    main()
