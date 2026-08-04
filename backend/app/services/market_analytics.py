"""AI Market Analytics — biznes uchun bozor tendensiyalari.

Misollar:
  "Rossiyada hozir quyosh panellariga talab oshmoqda."
  "Qozog‘istonda sement importi ko‘paygan."
"""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.product import Product, ProductView
from app.models.user import BusinessProfile, User
from app.services.products import PRODUCT_CATEGORIES

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_FALLBACK_MARKETS = ["RU", "KZ", "TR", "UZ", "AE", "CN"]

_COUNTRY_NAMES = {
    "uz": {
        "RU": "Rossiya",
        "KZ": "Qozog‘iston",
        "TR": "Turkiya",
        "UZ": "O‘zbekiston",
        "AE": "BAA",
        "CN": "Xitoy",
        "DE": "Germaniya",
        "US": "AQSH",
    },
    "ru": {
        "RU": "Россия",
        "KZ": "Казахстан",
        "TR": "Турция",
        "UZ": "Узбекистан",
        "AE": "ОАЭ",
        "CN": "Китай",
        "DE": "Германия",
        "US": "США",
    },
    "en": {
        "RU": "Russia",
        "KZ": "Kazakhstan",
        "TR": "Turkey",
        "UZ": "Uzbekistan",
        "AE": "UAE",
        "CN": "China",
        "DE": "Germany",
        "US": "USA",
    },
}

# Kategoriya / so‘z → odam tushunarli mavzu (fallback; asosan PRODUCT_CATEGORIES).
_TOPIC_LABELS = {
    "uz": {
        "clothing_accessories": "to‘qimachilik mahsulotlari",
        "pottery": "kulolchilik",
        "woodwork": "yog‘och buyumlar",
        "jewelry": "taqinchoqlar",
        "agriculture_food": "oziq-ovqat",
        "building_materials": "qurilish materiallari",
        "consumer_electronics": "elektronika",
        "energy_solar": "quyosh panellari",
        "fabric_textiles": "to‘qimachilik",
        "industrial_machinery": "sanoat uskunalari",
        "health_medical": "tibbiy mahsulotlar",
        "other": "sanoat mahsulotlari",
        "solar": "quyosh panellari",
        "cement": "sement",
        "textile": "to‘qimachilik",
        "construction": "qurilish materiallari",
    },
    "ru": {
        "clothing_accessories": "текстиль",
        "pottery": "керамика",
        "woodwork": "изделия из дерева",
        "jewelry": "украшения",
        "agriculture_food": "продукты питания",
        "building_materials": "стройматериалы",
        "consumer_electronics": "электроника",
        "energy_solar": "солнечные панели",
        "fabric_textiles": "текстиль",
        "industrial_machinery": "промышленное оборудование",
        "health_medical": "медицина",
        "other": "промышленные товары",
        "solar": "солнечные панели",
        "cement": "цемент",
        "textile": "текстиль",
        "construction": "строительные материалы",
    },
    "en": {
        "clothing_accessories": "textiles",
        "pottery": "pottery",
        "woodwork": "wood products",
        "jewelry": "jewelry",
        "agriculture_food": "food products",
        "building_materials": "building materials",
        "consumer_electronics": "electronics",
        "energy_solar": "solar panels",
        "fabric_textiles": "textiles",
        "industrial_machinery": "industrial machinery",
        "health_medical": "medical goods",
        "other": "industrial goods",
        "solar": "solar panels",
        "cement": "cement",
        "textile": "textiles",
        "construction": "construction materials",
    },
}


def _locale(code: str) -> str:
    c = (code or "uz").lower().split("_")[0]
    if c in {"ru", "rus"}:
        return "ru"
    if c in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


def _country_label(cc: str, locale: str) -> str:
    return _COUNTRY_NAMES.get(locale, _COUNTRY_NAMES["uz"]).get(cc.upper(), cc.upper())


def _topic_label(key: str, locale: str) -> str:
    return _TOPIC_LABELS.get(locale, _TOPIC_LABELS["uz"]).get(key, key)


def _message_template(
    *,
    country_label: str,
    topic_label: str,
    trend: str,
    locale: str,
) -> str:
    if locale == "ru":
        if trend == "import_up":
            return f"В {country_label} импорт {topic_label} вырос."
        if trend == "demand_down":
            return f"В {country_label} спрос на {topic_label} снижается."
        return f"В {country_label} сейчас растёт спрос на {topic_label}."
    if locale == "en":
        if trend == "import_up":
            return f"{topic_label.capitalize()} imports have increased in {country_label}."
        if trend == "demand_down":
            return f"Demand for {topic_label} is slowing in {country_label}."
        return f"Demand for {topic_label} is rising in {country_label} right now."
    # uz
    if trend == "import_up":
        return f"{country_label}da {topic_label} importi ko‘paygan."
    if trend == "demand_down":
        return f"{country_label}da {topic_label}ga talab pasaymoqda."
    return f"{country_label}da hozir {topic_label}ga talab oshmoqda."


def _detect_topic_keys(text: str) -> list[str]:
    blob = (text or "").lower()
    keys: list[str] = []
    mapping = [
        ("solar", ("solar", "quyosh", "панел", "panel", "pv ")),
        ("cement", ("cement", "sement", "цемент")),
        ("textile", ("textile", "toqimach", "to‘qimach", "текстил", "fabric")),
        ("construction", ("construction", "qurilish", "строител", "steel", " арматур")),
    ]
    for key, words in mapping:
        if any(w in blob for w in words):
            keys.append(key)
    return keys


async def _view_signals(db: AsyncSession) -> list[dict]:
    """Davlat + kategoriya bo‘yicha so‘nggi 30 kun vs oldingi 30 kun ko‘rishlar."""
    now = datetime.now(UTC)
    cur_from = (now - timedelta(days=30)).strftime("%Y-%m-%d")
    prev_from = (now - timedelta(days=60)).strftime("%Y-%m-%d")
    prev_to = cur_from

    async def _bucket(day_from: str, day_to: str | None) -> dict[tuple[str, str], int]:
        q = (
            select(
                func.coalesce(BusinessProfile.country, User.country).label("cc"),
                Product.category,
                func.count(ProductView.id),
            )
            .select_from(ProductView)
            .join(Product, Product.id == ProductView.product_id)
            .join(User, User.id == ProductView.user_id)
            .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
            .where(ProductView.day_bucket >= day_from)
            .group_by(
                func.coalesce(BusinessProfile.country, User.country),
                Product.category,
            )
        )
        if day_to:
            q = q.where(ProductView.day_bucket < day_to)
        result = await db.execute(q)
        out: dict[tuple[str, str], int] = {}
        for cc, cat, cnt in result.all():
            code = (cc or "").strip().upper()
            if len(code) != 2:
                continue
            out[(code, str(cat or "other"))] = int(cnt or 0)
        return out

    current = await _bucket(cur_from, None)
    previous = await _bucket(prev_from, prev_to)

    signals: list[dict] = []
    keys = set(current) | set(previous)
    for key in keys:
        cur = current.get(key, 0)
        prev = previous.get(key, 0)
        if cur < 5 and prev < 5:
            continue
        growth = 0.0
        if prev <= 0:
            if cur >= 8:
                growth = 1.0
            else:
                continue
        else:
            growth = (cur - prev) / max(prev, 1)
        if abs(growth) < 0.25 and cur < 15:
            continue
        cc, cat = key
        trend = "demand_up" if growth >= 0 else "demand_down"
        if growth >= 0.8:
            # Kuchli o‘sish — import/talab signaliga yaqin
            trend = "demand_up"
        signals.append(
            {
                "country": cc,
                "category": cat,
                "topic_key": cat,
                "trend": trend,
                "growth": round(growth, 2),
                "current_views": cur,
                "previous_views": prev,
                "signal": "views_growth",
            }
        )
    signals.sort(key=lambda s: abs(float(s["growth"])), reverse=True)
    return signals[:12]


async def _listing_signals(db: AsyncSession) -> list[dict]:
    """Yangi e’lonlar o‘sishi — ‘import/supply’ proxy."""
    now = datetime.now(UTC)
    cur_from = now - timedelta(days=30)
    prev_from = now - timedelta(days=60)

    async def _bucket(ts_from: datetime, ts_to: datetime | None) -> dict[tuple[str, str], int]:
        q = (
            select(
                func.coalesce(BusinessProfile.country, User.country).label("cc"),
                Product.category,
                func.count(Product.id),
            )
            .select_from(Product)
            .join(User, User.id == Product.seller_id)
            .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
            .where(
                Product.status == "published",
                Product.created_at >= ts_from,
            )
            .group_by(
                func.coalesce(BusinessProfile.country, User.country),
                Product.category,
            )
        )
        if ts_to:
            q = q.where(Product.created_at < ts_to)
        result = await db.execute(q)
        out: dict[tuple[str, str], int] = {}
        for cc, cat, cnt in result.all():
            code = (cc or "").strip().upper()
            if len(code) != 2:
                continue
            out[(code, str(cat or "other"))] = int(cnt or 0)
        return out

    current = await _bucket(cur_from, None)
    previous = await _bucket(prev_from, cur_from)
    signals: list[dict] = []
    for key in set(current) | set(previous):
        cur = current.get(key, 0)
        prev = previous.get(key, 0)
        if cur < 3 and prev < 3:
            continue
        growth = 1.0 if prev <= 0 and cur >= 4 else ((cur - prev) / max(prev, 1))
        if growth < 0.35:
            continue
        cc, cat = key
        signals.append(
            {
                "country": cc,
                "category": cat,
                "topic_key": cat,
                "trend": "import_up",
                "growth": round(float(growth), 2),
                "current_listings": cur,
                "previous_listings": prev,
                "signal": "listings_growth",
            }
        )
    signals.sort(key=lambda s: float(s["growth"]), reverse=True)
    return signals[:8]


def _seller_focus(user: User, products: list[Product]) -> dict:
    biz = user.business
    parts: list[str] = []
    cats: list[str] = []
    if biz and biz.company_name:
        parts.append(biz.company_name)
    if biz and biz.keywords:
        parts.extend(str(k) for k in biz.keywords[:8])
    for p in products[:12]:
        if p.name:
            parts.append(p.name)
        if p.category and p.category not in cats:
            cats.append(p.category)
    export = [
        str(c).strip().upper()
        for c in ((biz.export_countries if biz else None) or [])
        if str(c).strip() and len(str(c).strip()) == 2
    ]
    blob = " ".join(parts)
    topic_keys = _detect_topic_keys(blob)
    topic_keys.extend(cats)
    # unique
    seen: set[str] = set()
    topics: list[str] = []
    for t in topic_keys:
        if t and t not in seen:
            seen.add(t)
            topics.append(t)
    return {
        "summary": ", ".join(dict.fromkeys(p.strip() for p in parts if p.strip()))[:240],
        "topics": topics[:6],
        "categories": cats[:6],
        "export_countries": export[:8] or list(_FALLBACK_MARKETS),
    }


def _fallback_curated(locale: str, focus: dict) -> list[dict]:
    """Ma’lumot kam bo‘lsa — fokusga mos qimmatli namuna insight’lar."""
    markets = focus.get("export_countries") or _FALLBACK_MARKETS
    topics = focus.get("topics") or ["other"]
    items: list[dict] = []
    pairs = [
        (markets[0] if markets else "RU", topics[0], "demand_up"),
        (
            markets[1] if len(markets) > 1 else "KZ",
            topics[1] if len(topics) > 1 else topics[0],
            "import_up",
        ),
        (
            markets[2] if len(markets) > 2 else "TR",
            topics[0],
            "demand_up",
        ),
    ]
    # Prefer solar/cement style if not in topics — still useful general
    if "solar" not in topics and "cement" not in topics:
        pairs = [
            ("RU", "solar", "demand_up"),
            ("KZ", "cement", "import_up"),
            (markets[0] if markets else "TR", topics[0], "demand_up"),
        ]
    for cc, topic, trend in pairs[:3]:
        country_label = _country_label(cc, locale)
        topic_label = _topic_label(topic, locale)
        items.append(
            {
                "country": cc,
                "topic": topic,
                "trend": trend,
                "message": _message_template(
                    country_label=country_label,
                    topic_label=topic_label,
                    trend=trend,
                    locale=locale,
                ),
                "confidence": 0.45,
                "signal": "curated",
            }
        )
    return items


async def _openai_insights(
    *,
    locale: str,
    focus: dict,
    signals: list[dict],
) -> list[dict]:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        return []
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    lang = {"uz": "Uzbek", "ru": "Russian", "en": "English"}.get(locale, "Uzbek")
    system = (
        "You are AnyTrade AI Market Analytics for B2B exporters. "
        f"Write 3-5 short market insights in {lang}. "
        "Reply ONLY JSON: "
        '{"items":[{"country":"RU","topic":"solar panels","trend":"demand_up|import_up|demand_down",'
        '"message":"...","confidence":0.0-1.0}]}. '
        "Style examples: "
        "'Rossiyada hozir quyosh panellariga talab oshmoqda.' / "
        "'Qozog‘istonda sement importi ko‘paygan.' "
        "Use marketplace signals when present; otherwise give plausible regional trade tips "
        "relevant to the seller focus. One sentence each. Never invent exact percentages."
    )
    user = json.dumps(
        {
            "seller_focus": focus,
            "signals": signals[:10],
            "country_names": _COUNTRY_NAMES.get(locale, _COUNTRY_NAMES["uz"]),
        },
        ensure_ascii=False,
    )
    payload = {
        "model": model,
        "temperature": 0.35,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
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
        out: list[dict] = []
        for item in parsed.get("items") or []:
            if not isinstance(item, dict):
                continue
            cc = str(item.get("country") or "").strip().upper()
            msg = str(item.get("message") or "").strip()
            if len(cc) != 2 or not msg:
                continue
            trend = str(item.get("trend") or "demand_up").strip()
            if trend not in {"demand_up", "import_up", "demand_down"}:
                trend = "demand_up"
            conf = item.get("confidence")
            try:
                confidence = float(conf) if conf is not None else 0.7
            except (TypeError, ValueError):
                confidence = 0.7
            out.append(
                {
                    "country": cc,
                    "topic": str(item.get("topic") or "").strip()[:80],
                    "trend": trend,
                    "message": msg[:220],
                    "confidence": max(0.0, min(1.0, confidence)),
                    "signal": "ai",
                }
            )
            if len(out) >= 5:
                break
        return out
    except Exception as exc:
        logger.warning("market_analytics openai failed: %s", exc)
        return []


def _rules_from_signals(signals: list[dict], locale: str) -> list[dict]:
    items: list[dict] = []
    for s in signals[:5]:
        cc = s["country"]
        topic_key = s.get("topic_key") or s.get("category") or "other"
        trend = s.get("trend") or "demand_up"
        country_label = _country_label(cc, locale)
        topic_label = _topic_label(str(topic_key), locale)
        # Prefer category title from PRODUCT_CATEGORIES if available
        cat = s.get("category")
        if cat in PRODUCT_CATEGORIES:
            lang_key = {"uz": "uz_UZ", "ru": "ru_RU", "en": "us_US"}.get(locale, "uz_UZ")
            topic_label = PRODUCT_CATEGORIES[cat].get(lang_key) or topic_label
        growth = abs(float(s.get("growth") or 0))
        items.append(
            {
                "country": cc,
                "topic": topic_label,
                "trend": trend,
                "message": _message_template(
                    country_label=country_label,
                    topic_label=topic_label.lower() if locale != "en" else topic_label.lower(),
                    trend=trend,
                    locale=locale,
                ),
                "confidence": min(0.92, 0.5 + growth * 0.25),
                "signal": s.get("signal") or "rules",
            }
        )
    return items


async def get_market_analytics(
    db: AsyncSession,
    *,
    user: User,
    locale: str = "uz",
) -> dict:
    if not user.is_business or user.business is None:
        raise AppError(
            message="AI Market Analytics faqat Business akkaunt uchun",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )

    loc = _locale(locale)
    result = await db.execute(
        select(Product)
        .where(Product.seller_id == user.id, Product.status == "published")
        .order_by(Product.created_at.desc())
        .limit(40)
    )
    products = list(result.scalars().all())
    focus = _seller_focus(user, products)

    view_sigs = await _view_signals(db)
    list_sigs = await _listing_signals(db)

    # Prefer signals in seller export markets / topics
    export = set(focus.get("export_countries") or [])
    topics = set(focus.get("topics") or [])
    cats = set(focus.get("categories") or [])

    def _rank(s: dict) -> float:
        score = abs(float(s.get("growth") or 0))
        if s.get("country") in export:
            score += 0.5
        if s.get("category") in cats or s.get("topic_key") in topics:
            score += 0.4
        return score

    merged = sorted(view_sigs + list_sigs, key=_rank, reverse=True)

    ai_items = await _openai_insights(locale=loc, focus=focus, signals=merged)
    generated_by = "openai" if ai_items else "rules"
    items = ai_items if ai_items else _rules_from_signals(merged, loc)
    if not items:
        items = _fallback_curated(loc, focus)
        generated_by = "curated"

    return {
        "focus_summary": focus.get("summary") or "",
        "items": items[:5],
        "generated_by": generated_by,
    }
