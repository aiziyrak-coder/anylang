"""AI Matching — sotuvchiga qaysi davlatlarda qancha kompaniya mahsulot qidirayotganini tavsiya qiladi."""

from __future__ import annotations

import json
import logging
from collections import defaultdict

import httpx
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.product import Product, ProductFavorite, ProductView
from app.models.user import BusinessProfile, Subscription, User

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_BUYER_ROLES = {"distributor", "retail", "service"}
_FALLBACK_MARKETS = ["TR", "RU", "KZ", "AE", "DE", "CN", "UZ"]

_COUNTRY_NAMES = {
    "uz": {
        "TR": "Turkiya",
        "RU": "Rossiya",
        "KZ": "Qozog‘iston",
        "AE": "BAA",
        "DE": "Germaniya",
        "CN": "Xitoy",
        "UZ": "O‘zbekiston",
        "US": "AQSH",
        "GB": "Buyuk Britaniya",
        "IN": "Hindiston",
        "KR": "Janubiy Koreya",
        "JP": "Yaponiya",
        "FR": "Fransiya",
        "IT": "Italiya",
        "PL": "Polsha",
    },
    "ru": {
        "TR": "Турция",
        "RU": "Россия",
        "KZ": "Казахстан",
        "AE": "ОАЭ",
        "DE": "Германия",
        "CN": "Китай",
        "UZ": "Узбекистан",
        "US": "США",
        "GB": "Великобритания",
        "IN": "Индия",
        "KR": "Южная Корея",
        "JP": "Япония",
        "FR": "Франция",
        "IT": "Италия",
        "PL": "Польша",
    },
    "en": {
        "TR": "Turkey",
        "RU": "Russia",
        "KZ": "Kazakhstan",
        "AE": "UAE",
        "DE": "Germany",
        "CN": "China",
        "UZ": "Uzbekistan",
        "US": "USA",
        "GB": "United Kingdom",
        "IN": "India",
        "KR": "South Korea",
        "JP": "Japan",
        "FR": "France",
        "IT": "Italy",
        "PL": "Poland",
    },
}


def _locale(code: str) -> str:
    c = (code or "uz").lower().split("_")[0]
    if c in {"ru", "rus"}:
        return "ru"
    if c in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


def _country_label(code: str, locale: str) -> str:
    cc = (code or "").upper()
    return _COUNTRY_NAMES.get(locale, _COUNTRY_NAMES["uz"]).get(cc, cc)


def _message_template(*, country_label: str, count: int, locale: str) -> str:
    if locale == "ru":
        return f"В {country_label} ваш товар ищут {count} компаний."
    if locale == "en":
        return f"There are {count} companies in {country_label} looking for your product."
    return f"{country_label}da sizning mahsulotingizni qidirayotgan {count} ta kompaniya bor."


async def _openai_messages(
    *,
    locale: str,
    product_summary: str,
    rows: list[dict],
) -> dict[str, str]:
    """country -> message. Empty dict on failure."""
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key or not rows:
        return {}
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    lang = {"uz": "Uzbek", "ru": "Russian", "en": "English"}.get(locale, "Uzbek")
    system = (
        "You are AnyTrade AI Matching. Write short B2B match insights. "
        f"Reply ONLY JSON: {{\"messages\":[{{\"country\":\"TR\",\"message\":\"...\"}}]}}. "
        f"Write each message in {lang}. "
        "Use ONLY the given counts — never invent numbers. "
        "Tone: confident marketplace advice, one sentence each. "
        "Example style: 'There are 18 companies in Turkey looking for your product.'"
    )
    user = json.dumps(
        {
            "seller_products": product_summary,
            "matches": [
                {
                    "country": r["country"],
                    "country_name": r["country_label"],
                    "count": r["count"],
                }
                for r in rows
            ],
        },
        ensure_ascii=False,
    )
    payload = {
        "model": model,
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=40.0) as client:
            resp = await client.post(
                OPENAI_CHAT_URL,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
        ).strip()
        parsed = json.loads(content) if content else {}
        out: dict[str, str] = {}
        for item in parsed.get("messages") or []:
            if not isinstance(item, dict):
                continue
            cc = str(item.get("country") or "").strip().upper()
            msg = str(item.get("message") or "").strip()
            if cc and msg:
                out[cc] = msg[:280]
        return out
    except Exception as exc:
        logger.warning("ai_matching openai failed: %s", exc)
        return {}


async def _seller_products(db: AsyncSession, user_id: int) -> list[Product]:
    result = await db.execute(
        select(Product)
        .where(
            Product.seller_id == user_id,
            Product.status == "published",
        )
        .order_by(Product.created_at.desc())
        .limit(40)
    )
    return list(result.scalars().all())


def _product_summary(products: list[Product], business: BusinessProfile | None) -> str:
    parts: list[str] = []
    if business and business.company_name:
        parts.append(business.company_name)
    if business and business.business_role:
        parts.append(business.business_role)
    if business and business.keywords:
        parts.extend(str(k) for k in business.keywords[:8])
    cats = []
    for p in products[:12]:
        if p.name:
            parts.append(p.name)
        if p.category and p.category not in cats:
            cats.append(p.category)
    parts.extend(cats)
    # unique keep order
    seen: set[str] = set()
    out: list[str] = []
    for p in parts:
        key = p.strip().lower()
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(p.strip())
        if len(out) >= 16:
            break
    return ", ".join(out)


async def _interest_from_views_favorites(
    db: AsyncSession,
    *,
    product_ids: list[int],
) -> dict[str, set[int]]:
    """country -> set(user_id) who viewed/favorited seller products."""
    by_country: dict[str, set[int]] = defaultdict(set)
    if not product_ids:
        return by_country

    view_q = await db.execute(
        select(User.id, User.country, BusinessProfile.country)
        .select_from(ProductView)
        .join(User, User.id == ProductView.user_id)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .where(ProductView.product_id.in_(product_ids))
    )
    for uid, user_country, biz_country in view_q.all():
        cc = ((biz_country or user_country or "")).strip().upper()
        if len(cc) == 2:
            by_country[cc].add(int(uid))

    fav_q = await db.execute(
        select(User.id, User.country, BusinessProfile.country)
        .select_from(ProductFavorite)
        .join(User, User.id == ProductFavorite.user_id)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .where(ProductFavorite.product_id.in_(product_ids))
    )
    for uid, user_country, biz_country in fav_q.all():
        cc = ((biz_country or user_country or "")).strip().upper()
        if len(cc) == 2:
            by_country[cc].add(int(uid))
    return by_country


async def _buyer_companies_by_country(
    db: AsyncSession,
    *,
    seller_id: int,
    markets: list[str],
    keywords: list[str],
) -> dict[str, list[dict]]:
    """Davlat bo‘yicha potensial xaridor bizneslar (distributor/retail/service)."""
    by_country: dict[str, list[dict]] = defaultdict(list)
    if not markets:
        return by_country

    result = await db.execute(
        select(User, BusinessProfile, Subscription)
        .join(BusinessProfile, BusinessProfile.user_id == User.id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(
            User.id != seller_id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            Subscription.plan == "business",
            Subscription.is_active.is_(True),
            or_(
                BusinessProfile.country.in_(markets),
                BusinessProfile.business_role.in_(list(_BUYER_ROLES)),
            ),
        )
        .limit(400)
    )
    kw_lower = [k.lower() for k in keywords if k.strip()]
    for user, biz, _sub in result.all():
        cc = (biz.country or user.country or "").strip().upper()
        if len(cc) != 2:
            continue
        # Prefer markets list; also include if export_countries overlaps markets
        export = [
            str(c).strip().upper()
            for c in (biz.export_countries or [])
            if str(c).strip()
        ]
        in_market = cc in markets or any(e in markets for e in export)
        if not in_market:
            continue
        # Keyword soft boost — keep all buyers in market, flag relevance
        blob = " ".join(
            [
                biz.company_name or "",
                biz.description or "",
                " ".join(str(k) for k in (biz.keywords or [])),
            ]
        ).lower()
        relevant = True
        if kw_lower:
            relevant = any(k in blob for k in kw_lower) or biz.business_role in _BUYER_ROLES
        if not relevant and biz.business_role not in _BUYER_ROLES:
            continue
        target_cc = cc if cc in markets else next((e for e in export if e in markets), cc)
        if target_cc not in markets:
            continue
        by_country[target_cc].append(
            {
                "id": int(user.id),
                "name": (biz.company_name or user.full_name or "").strip() or f"Company #{user.id}",
                "country": cc,
                "business_role": biz.business_role,
                "logo_url": biz.logo_url,
            }
        )
    return by_country


async def get_matches(
    db: AsyncSession,
    *,
    user: User,
    locale: str = "uz",
) -> dict:
    if not user.is_business or user.business is None:
        raise AppError(
            message="AI Matching faqat Business akkaunt uchun",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )

    loc = _locale(locale)
    business = user.business
    products = await _seller_products(db, user.id)
    summary = _product_summary(products, business)
    product_ids = [p.id for p in products]

    export = [
        str(c).strip().upper()
        for c in (business.export_countries or [])
        if str(c).strip() and len(str(c).strip()) == 2
    ]
    markets = export[:8] if export else list(_FALLBACK_MARKETS)
    # Always include a couple of strong markets for manufacturers
    for extra in ("TR", "RU", "KZ"):
        if extra not in markets:
            markets.append(extra)
        if len(markets) >= 8:
            break

    keywords: list[str] = []
    for p in products[:10]:
        keywords.extend((p.name or "").split()[:3])
    keywords.extend(str(k) for k in (business.keywords or [])[:8])
    keywords = [k for k in keywords if len(k) >= 3][:12]

    interest = await _interest_from_views_favorites(db, product_ids=product_ids)
    buyers = await _buyer_companies_by_country(
        db,
        seller_id=user.id,
        markets=markets,
        keywords=keywords,
    )

    # Merge: unique companies/users per country
    merged: dict[str, dict[int, dict]] = defaultdict(dict)
    for cc, uids in interest.items():
        if cc not in markets and cc not in export:
            # still keep strong interest countries
            pass
        for uid in uids:
            merged[cc][uid] = {
                "id": uid,
                "name": f"Buyer #{uid}",
                "country": cc,
                "business_role": None,
                "logo_url": None,
            }

    for cc, companies in buyers.items():
        for company in companies:
            merged[cc][int(company["id"])] = company

    # Enrich names for interest-only users (batch)
    orphan_ids = [
        uid
        for cc, mmap in merged.items()
        for uid, row in mmap.items()
        if row["name"].startswith("Buyer #")
    ]
    if orphan_ids:
        result = await db.execute(
            select(User, BusinessProfile)
            .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
            .where(User.id.in_(orphan_ids[:200]))
        )
        for u, biz in result.all():
            name = (biz.company_name if biz and biz.company_name else u.full_name) or f"User #{u.id}"
            logo = biz.logo_url if biz else None
            role = biz.business_role if biz else None
            for cc, mmap in merged.items():
                if u.id in mmap:
                    mmap[u.id] = {
                        "id": int(u.id),
                        "name": name.strip(),
                        "country": cc,
                        "business_role": role,
                        "logo_url": logo,
                    }

    rows_raw: list[dict] = []
    for cc, mmap in merged.items():
        count = len(mmap)
        if count <= 0:
            continue
        samples = list(mmap.values())[:5]
        rows_raw.append(
            {
                "country": cc,
                "country_label": _country_label(cc, loc),
                "count": count,
                "samples": samples,
            }
        )
    rows_raw.sort(key=lambda r: r["count"], reverse=True)
    rows_raw = rows_raw[:6]

    ai_msgs = await _openai_messages(locale=loc, product_summary=summary, rows=rows_raw)
    generated_by = "openai" if ai_msgs else "rules"

    items: list[dict] = []
    for row in rows_raw:
        cc = row["country"]
        msg = ai_msgs.get(cc) or _message_template(
            country_label=row["country_label"],
            count=row["count"],
            locale=loc,
        )
        items.append(
            {
                "country": cc,
                "count": row["count"],
                "message": msg,
                "match_type": "buyers_looking",
                "sample_companies": row["samples"],
            }
        )

    return {
        "product_summary": summary,
        "items": items,
        "generated_by": generated_by,
    }


_COMPLEMENTARY_ROLES: dict[str, set[str]] = {
    "manufacturer": {"distributor", "retail", "service", "manufacturer"},
    "distributor": {"manufacturer", "retail", "distributor"},
    "retail": {"manufacturer", "distributor", "retail"},
    "service": {"manufacturer", "distributor", "service"},
}


def _match_percent(
    *,
    viewer_role: str | None,
    candidate_role: str | None,
    viewer_keywords: list[str],
    candidate_blob: str,
    country_overlap: bool,
    verified: bool,
) -> int:
    score = 48
    vr = (viewer_role or "").strip().lower()
    cr = (candidate_role or "").strip().lower()
    if vr and cr:
        if cr in _COMPLEMENTARY_ROLES.get(vr, set()):
            score += 28 if cr != vr else 18
        elif cr == vr:
            score += 18
    hits = 0
    blob = candidate_blob.lower()
    for kw in viewer_keywords:
        if kw and kw in blob:
            hits += 1
    score += min(28, hits * 7)
    if country_overlap:
        score += 12
    if verified:
        score += 5
    return max(55, min(98, score))


async def get_recommendations(
    db: AsyncSession,
    *,
    user: User,
    locale: str = "uz",
    limit: int = 12,
) -> dict:
    """Soha (rol + keywords) bo‘yicha foydalanuvchi tavsiyalari."""
    from app.models.chat import Friendship

    loc = _locale(locale)
    safe_limit = min(max(int(limit or 12), 1), 30)

    # Exclude friends + self
    friendships = await db.execute(
        select(Friendship).where(
            Friendship.status.in_(("accepted", "pending")),
            or_(Friendship.user_low_id == user.id, Friendship.user_high_id == user.id),
        )
    )
    exclude: set[int] = {user.id}
    for f in friendships.scalars().all():
        other = f.user_high_id if f.user_low_id == user.id else f.user_low_id
        exclude.add(int(other))

    business = user.business if getattr(user, "business", None) is not None else None
    viewer_role = (business.business_role if business else None) or None
    viewer_country = (
        (business.country if business and business.country else None)
        or user.country
        or ""
    ).strip().upper()
    viewer_export = [
        str(c).strip().upper()
        for c in ((business.export_countries if business else None) or [])
        if str(c).strip() and len(str(c).strip()) == 2
    ]
    products = await _seller_products(db, user.id) if user.is_business else []
    keywords: list[str] = []
    if business and business.keywords:
        keywords.extend(str(k).strip().lower() for k in business.keywords if str(k).strip())
    for p in products[:10]:
        for token in (p.name or "").split()[:3]:
            if len(token) >= 3:
                keywords.append(token.lower())
        if p.category:
            keywords.append(str(p.category).strip().lower())
    # unique
    seen_kw: set[str] = set()
    viewer_keywords: list[str] = []
    for k in keywords:
        if k in seen_kw:
            continue
        seen_kw.add(k)
        viewer_keywords.append(k)
        if len(viewer_keywords) >= 16:
            break

    based_bits = []
    if viewer_role:
        based_bits.append(viewer_role)
    based_bits.extend(viewer_keywords[:4])
    based_on = ", ".join(based_bits) if based_bits else _country_label(viewer_country, loc)

    result = await db.execute(
        select(User, BusinessProfile, Subscription)
        .join(BusinessProfile, BusinessProfile.user_id == User.id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(
            User.id.notin_(list(exclude)),
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            Subscription.plan == "business",
            Subscription.is_active.is_(True),
        )
        .limit(500)
    )

    scored: list[dict] = []
    for cand, biz, _sub in result.all():
        if cand.id in exclude:
            continue
        company = (biz.company_name or cand.full_name or "").strip() or f"Company #{cand.id}"
        cc = (biz.country or cand.country or "").strip().upper()
        if len(cc) != 2:
            cc = None
        role = (biz.business_role or None)
        blob = " ".join(
            [
                company,
                biz.description or "",
                " ".join(str(k) for k in (biz.keywords or [])),
                role or "",
            ]
        )
        export = [
            str(c).strip().upper()
            for c in (biz.export_countries or [])
            if str(c).strip()
        ]
        country_overlap = False
        if viewer_country and cc and viewer_country == cc:
            country_overlap = True
        if viewer_export and (cc in viewer_export or any(e in viewer_export for e in export)):
            country_overlap = True
        if viewer_country and viewer_country in export:
            country_overlap = True

        verified = bool(cand.verified_badge or biz.documents_verified)
        percent = _match_percent(
            viewer_role=viewer_role,
            candidate_role=role,
            viewer_keywords=viewer_keywords,
            candidate_blob=blob,
            country_overlap=country_overlap,
            verified=verified,
        )
        # Require some signal: keywords or complementary role or country
        if percent < 60 and not country_overlap and not viewer_keywords:
            continue
        if percent < 62 and not viewer_role and not viewer_keywords:
            # Oddiy foydalanuvchi — faqat yaqin davlatlar
            if not country_overlap:
                continue

        cand_keywords = [
            str(k).strip()
            for k in (biz.keywords or [])
            if str(k).strip()
        ]
        reason = _recommendation_reason(
            locale=loc,
            country=cc,
            role=role,
            percent=percent,
        )
        headline = _match_headline(
            locale=loc,
            role=role,
            keywords=cand_keywords,
            company=company,
        )
        scored.append(
            {
                "user_id": int(cand.id),
                "company_name": company[:200],
                "country": cc,
                "business_role": role,
                "logo_url": biz.logo_url,
                "match_percent": percent,
                "reason": reason,
                "verified": verified,
                "headline": headline[:120],
            }
        )

    scored.sort(key=lambda x: (x["match_percent"], x["verified"]), reverse=True)
    return {
        "items": scored[:safe_limit],
        "based_on": based_on[:120],
        "total_count": len(scored),
    }


_ROLE_LABELS = {
    "uz": {
        "manufacturer": "Ishlab chiqaruvchi",
        "distributor": "Distributor",
        "retail": "Chakana",
        "service": "Xizmat",
        "importer": "Importyor",
        "exporter": "Eksportyor",
    },
    "ru": {
        "manufacturer": "Производитель",
        "distributor": "Дистрибьютор",
        "retail": "Ритейл",
        "service": "Услуги",
        "importer": "Импортёр",
        "exporter": "Экспортёр",
    },
    "en": {
        "manufacturer": "Manufacturer",
        "distributor": "Distributor",
        "retail": "Retailer",
        "service": "Service",
        "importer": "Importer",
        "exporter": "Exporter",
    },
}


def _role_label(role: str | None, locale: str) -> str:
    raw = (role or "").strip().lower()
    if not raw:
        return ""
    return _ROLE_LABELS.get(locale, _ROLE_LABELS["uz"]).get(raw, raw.replace("_", " ").title())


def _match_headline(
    *,
    locale: str,
    role: str | None,
    keywords: list[str],
    company: str,
) -> str:
    """Masalan: «Furniture Importer» — keyword + rol."""
    role_l = _role_label(role, locale)
    kw = ""
    for k in keywords:
        token = k.strip()
        if len(token) < 3:
            continue
        # Skip role-like tokens
        if token.lower() in _ROLE_LABELS["en"] or token.lower() in {
            "manufacturer",
            "distributor",
            "retail",
            "service",
        }:
            continue
        kw = token.title() if token.islower() or token.isupper() else token
        break
    if kw and role_l:
        return f"{kw} {role_l}"
    if role_l:
        return role_l
    if kw:
        return kw
    return (company or "").strip()[:80]


def _recommendation_reason(
    *,
    locale: str,
    country: str | None,
    role: str | None,
    percent: int,
) -> str:
    label = _country_label(country or "", locale) if country else ""
    if locale == "ru":
        if label:
            return f"{label} · совпадение {percent}%"
        return f"Совпадение {percent}%"
    if locale == "en":
        if label:
            return f"{label} · {percent}% match"
        return f"{percent}% match"
    if label:
        return f"{label} · {percent}% mos"
    return f"{percent}% mos"
