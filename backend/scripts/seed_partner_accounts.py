"""Seed partner business accounts from docs/outreach/partner_credentials.csv.

Only rows with seed_ready=yes. Skips declined / placeholder names.
Creates verified business users + 1y business subscription + BusinessProfile.
Does NOT create products (partners upload after login / claim).

Usage (from backend/ with .env loaded):
  cd backend
  python -m scripts.seed_partner_accounts
  python -m scripts.seed_partner_accounts --dry-run
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

# Allow `python -m scripts.seed_partner_accounts` from backend/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import get_session_factory
from app.models.user import BusinessProfile, Subscription, User
from app.services.numbers import assign_random_standard_number

ROOT = Path(__file__).resolve().parents[2]
CREDS = ROOT / "docs" / "outreach" / "partner_credentials.csv"


def _lang_for(country: str) -> tuple[str, str]:
    c = country.upper()
    if c == "UZ":
        return "uz_UZ", "uz"
    if c in {"RU", "BY", "KZ", "KG", "TJ", "AM", "AZ", "MD"}:
        return "ru_RU", "ru"
    return "us_US", "en"


def _role_for(category: str) -> str:
    if category in {"services_b2b", "it_software"}:
        return "service"
    if category in {"agriculture_food"}:
        return "manufacturer"
    return "manufacturer"


async def seed(*, dry_run: bool) -> None:
    if not CREDS.exists():
        raise SystemExit(
            f"Missing {CREDS}. Run: python scripts/outreach/generate_partner_credentials.py"
        )

    rows = list(csv.DictReader(CREDS.open(encoding="utf-8-sig")))
    ready = [r for r in rows if (r.get("seed_ready") or "").strip() == "yes"]
    print(f"Credential rows: {len(rows)}; seed_ready: {len(ready)}; dry_run={dry_run}")

    if dry_run:
        for r in ready[:5]:
            print(f"  would create {r['id']} {r['email']} — {r['company_name'][:50]}")
        if len(ready) > 5:
            print(f"  ... +{len(ready) - 5} more")
        return

    factory = get_session_factory()
    created = 0
    skipped = 0
    updated_status: list[tuple[str, str]] = []

    async with factory() as db:
        for r in ready:
            email = (r.get("email") or "").strip().lower()
            password = (r.get("password") or "").strip()
            company = (r.get("company_name") or "").strip()
            country = (r.get("country") or "CN").strip().upper()[:2]
            category = (r.get("category_code") or "other").strip()
            website = (r.get("website") or "").strip() or None
            mid = (r.get("id") or "").strip()

            if not email or not password or not company:
                skipped += 1
                continue

            existing = (
                await db.execute(select(User).where(User.email == email))
            ).scalar_one_or_none()
            if existing is not None:
                print(f"skip exists {email}")
                updated_status.append((mid, "already_exists"))
                skipped += 1
                continue

            app_lang, native = _lang_for(country)
            number = await assign_random_standard_number(db)
            user = User(
                email=email,
                password_hash=hash_password(password),
                full_name=company[:100],
                number=number,
                birth_date=date(1985, 1, 1),
                gender="other",
                country=country,
                app_language=app_lang,
                native_language=native,
                is_verified=True,
                is_active=True,
                verified_badge=False,
            )
            db.add(user)
            await db.flush()

            now = datetime.now(UTC)
            sub = Subscription(
                user_id=user.id,
                plan="business",
                billing_cycle="yearly",
                started_at=now,
                expires_at=now + timedelta(days=365),
                auto_renew=False,
                is_active=True,
                source="partner_seed",
            )
            db.add(sub)

            desc = (
                f"{company} — AnyLang partner onboarding profile. "
                f"Category: {category}. Please complete catalog after login."
            )
            biz = BusinessProfile(
                user_id=user.id,
                company_name=company[:200],
                country=country,
                business_role=_role_for(category),
                website=(website[:255] if website else None),
                description=desc,
                keywords=[category] if category else [],
                payment_methods=["T/T"],
                export_countries=[],
                certificates=[],
                incoterms=[],
                description_i18n={},
            )
            db.add(biz)
            created += 1
            updated_status.append((mid, "created"))
            print(f"created {mid} {email}")

        await db.commit()

    # Update credentials CSV statuses
    by_id = {mid: st for mid, st in updated_status}
    out_rows = []
    for r in rows:
        mid = (r.get("id") or "").strip()
        if mid in by_id:
            r["account_status"] = by_id[mid]
            if by_id[mid] == "created":
                r["notes"] = "Biznes akkaunt yaratildi — login/parolni partnerga yuboring"
        out_rows.append(r)
    fields = list(rows[0].keys())
    with CREDS.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(out_rows)

    print(f"Done. created={created} skipped={skipped}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    asyncio.run(seed(dry_run=args.dry_run))


if __name__ == "__main__":
    main()
