"""Smart Search — tabiiy til so‘rovini marketplace filtrlariga aylantiradi.

Misollar:
  "Turkey textile factory" → country=TR, role=manufacturer, search=textile
  "Factory in Turkey" → country=TR, role=manufacturer
  "Arzon futbolka" → search=futbolka, sort=price_asc, category=clothing
  "Turkiyadagi to‘qimachilik ishlab chiqaruvchilari" → xuddi shu
"""

from __future__ import annotations

import json
import logging
import re
from decimal import Decimal

import httpx
from sqlalchemy import String, cast, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.product import Product
from app.models.user import BusinessProfile, User
from app.services import products as products_service

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_VALID_CATEGORIES = set(products_service.PRODUCT_CATEGORIES.keys())
_VALID_ROLES = {"manufacturer", "distributor", "retail", "service"}
_VALID_SORTS = {
    "newest",
    "price_asc",
    "price_desc",
    "most_viewed",
    "top",
    "recommended",
}

_COUNTRY_ALIASES: dict[str, str] = {
    "turkey": "TR",
    "turkiye": "TR",
    "türkiye": "TR",
    "turkiya": "TR",
    "турция": "TR",
    "туркии": "TR",
    "russia": "RU",
    "rossiya": "RU",
    "россия": "RU",
    "kazakhstan": "KZ",
    "qozogiston": "KZ",
    "qozoqiston": "KZ",
    "казахстан": "KZ",
    "china": "CN",
    "xitoy": "CN",
    "китай": "CN",
    "uae": "AE",
    "dubai": "AE",
    "баа": "AE",
    "оаэ": "AE",
    "germany": "DE",
    "germaniya": "DE",
    "германия": "DE",
    "uzbekistan": "UZ",
    "ozbekiston": "UZ",
    "o'zbekiston": "UZ",
    "ўзбекистон": "UZ",
    "узбекистан": "UZ",
    "usa": "US",
    "america": "US",
    "aqsh": "US",
    "india": "IN",
    "hindiston": "IN",
    "индия": "IN",
    "korea": "KR",
    "koreya": "KR",
    "japan": "JP",
    "yaponiya": "JP",
    "france": "FR",
    "fransiya": "FR",
    "italy": "IT",
    "italiya": "IT",
    "poland": "PL",
    "polsha": "PL",
    "uk": "GB",
    "britain": "GB",
    "vietnam": "VN",
    "vetnam": "VN",
    "вьетнам": "VN",
}

_ROLE_ALIASES: dict[str, str] = {
    "factory": "manufacturer",
    "factories": "manufacturer",
    "manufacturer": "manufacturer",
    "manufacturers": "manufacturer",
    "producer": "manufacturer",
    "producers": "manufacturer",
    "zavod": "manufacturer",
    "завод": "manufacturer",
    "заводы": "manufacturer",
    "ishlab": "manufacturer",
    "chiqaruvchi": "manufacturer",
    "chiqaruvchilar": "manufacturer",
    "производитель": "manufacturer",
    "производители": "manufacturer",
    "фабрика": "manufacturer",
    "distributor": "distributor",
    "distributors": "distributor",
    "distribyutor": "distributor",
    "дистрибьютор": "distributor",
    "wholesale": "distributor",
    "wholesaler": "distributor",
    "retail": "retail",
    "retailer": "retail",
    "магазин": "retail",
    "service": "service",
    "services": "service",
}

_CHEAP_TOKENS = {
    "cheap",
    "cheapest",
    "affordable",
    "budget",
    "lowcost",
    "low-cost",
    "arzon",
    "arzonroq",
    "engarzon",
    "дешево",
    "дешёвый",
    "дешевые",
    "недорого",
    "бюджет",
}
_EXPENSIVE_TOKENS = {
    "expensive",
    "premium",
    "luxury",
    "qimmat",
    "qimmatroq",
    "дорого",
    "премиум",
    "люкс",
}

_TOPIC_ALIASES: dict[str, tuple[str | None, str, dict[str, str]]] = {
    "textile": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "textiles": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "toqimachilik": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "to'qimachilik": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "тоқимачилик": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "текстиль": (
        "clothing_accessories",
        "textile",
        {"uz": "to‘qimachilik", "ru": "текстиль", "en": "textile"},
    ),
    "apparel": (
        "clothing_accessories",
        "apparel",
        {"uz": "kiyim", "ru": "одежда", "en": "apparel"},
    ),
    "clothing": (
        "clothing_accessories",
        "clothing",
        {"uz": "kiyim", "ru": "одежда", "en": "clothing"},
    ),
    "kiyim": (
        "clothing_accessories",
        "kiyim",
        {"uz": "kiyim", "ru": "одежда", "en": "clothing"},
    ),
    "одежда": (
        "clothing_accessories",
        "clothing",
        {"uz": "kiyim", "ru": "одежда", "en": "clothing"},
    ),
    "fashion": (
        "clothing_accessories",
        "fashion",
        {"uz": "moda", "ru": "мода", "en": "fashion"},
    ),
    "fabric": (
        "clothing_accessories",
        "fabric",
        {"uz": "mato", "ru": "ткань", "en": "fabric"},
    ),
    "futbolka": (
        "clothing_accessories",
        "futbolka",
        {"uz": "futbolka", "ru": "футболка", "en": "t-shirt"},
    ),
    "футболка": (
        "clothing_accessories",
        "futbolka",
        {"uz": "futbolka", "ru": "футболка", "en": "t-shirt"},
    ),
    "tshirt": (
        "clothing_accessories",
        "t-shirt",
        {"uz": "futbolka", "ru": "футболка", "en": "t-shirt"},
    ),
    "t-shirt": (
        "clothing_accessories",
        "t-shirt",
        {"uz": "futbolka", "ru": "футболка", "en": "t-shirt"},
    ),
    "tee": (
        "clothing_accessories",
        "t-shirt",
        {"uz": "futbolka", "ru": "футболка", "en": "t-shirt"},
    ),
    "shirt": (
        "clothing_accessories",
        "shirt",
        {"uz": "ko‘ylak", "ru": "рубашка", "en": "shirt"},
    ),
    "ko'ylak": (
        "clothing_accessories",
        "ko'ylak",
        {"uz": "ko‘ylak", "ru": "рубашка", "en": "shirt"},
    ),
    "koylak": (
        "clothing_accessories",
        "ko'ylak",
        {"uz": "ko‘ylak", "ru": "рубашка", "en": "shirt"},
    ),
    "jeans": (
        "clothing_accessories",
        "jeans",
        {"uz": "jinsi", "ru": "джинсы", "en": "jeans"},
    ),
    "jinsi": (
        "clothing_accessories",
        "jeans",
        {"uz": "jinsi", "ru": "джинсы", "en": "jeans"},
    ),
    "hoodie": (
        "clothing_accessories",
        "hoodie",
        {"uz": "tolstovka", "ru": "худи", "en": "hoodie"},
    ),
    "jewelry": ("jewelry", "jewelry", {"uz": "taqinchoq", "ru": "украшения", "en": "jewelry"}),
    "jewellery": ("jewelry", "jewelry", {"uz": "taqinchoq", "ru": "украшения", "en": "jewelry"}),
    "pottery": ("pottery", "pottery", {"uz": "kulolchilik", "ru": "керамика", "en": "pottery"}),
    "ceramic": ("pottery", "ceramic", {"uz": "kulolchilik", "ru": "керамика", "en": "ceramic"}),
    "wood": ("woodwork", "wood", {"uz": "yog‘och", "ru": "дерево", "en": "wood"}),
    "woodwork": ("woodwork", "woodwork", {"uz": "yog‘och", "ru": "дерево", "en": "woodwork"}),
}

_STOPWORDS = {
    "in",
    "the",
    "a",
    "an",
    "of",
    "for",
    "and",
    "or",
    "with",
    "from",
    "to",
    "da",
    "de",
    "dan",
    "ga",
    "ni",
    "va",
    "uchun",
    "kerak",
    "looking",
    "find",
    "search",
    "qidir",
    "qidiruv",
    "найти",
    "ищу",
    "поиск",
    "компании",
    "kompaniya",
    "kompaniyalar",
    "company",
    "companies",
    "want",
    "need",
    "please",
    "show",
    "me",
}

_COUNTRY_LABELS = {
    "uz": {
        "TR": "Turkiya",
        "RU": "Rossiya",
        "KZ": "Qozog‘iston",
        "CN": "Xitoy",
        "AE": "BAA",
        "DE": "Germaniya",
        "UZ": "O‘zbekiston",
        "US": "AQSH",
        "GB": "Buyuk Britaniya",
        "IN": "Hindiston",
        "KR": "Janubiy Koreya",
        "JP": "Yaponiya",
        "FR": "Fransiya",
        "IT": "Italiya",
        "PL": "Polsha",
        "VN": "Vetnam",
    },
    "ru": {
        "TR": "Турция",
        "RU": "Россия",
        "KZ": "Казахстан",
        "CN": "Китай",
        "AE": "ОАЭ",
        "DE": "Германия",
        "UZ": "Узбекистан",
        "US": "США",
        "GB": "Великобритания",
        "IN": "Индия",
        "KR": "Южная Корея",
        "JP": "Япония",
        "FR": "Франция",
        "IT": "Италия",
        "PL": "Польша",
        "VN": "Вьетнам",
    },
    "en": {
        "TR": "Turkey",
        "RU": "Russia",
        "KZ": "Kazakhstan",
        "CN": "China",
        "AE": "UAE",
        "DE": "Germany",
        "UZ": "Uzbekistan",
        "US": "USA",
        "GB": "United Kingdom",
        "IN": "India",
        "KR": "South Korea",
        "JP": "Japan",
        "FR": "France",
        "IT": "Italy",
        "PL": "Poland",
        "VN": "Vietnam",
    },
}

_ROLE_LABELS = {
    "uz": {
        "manufacturer": "ishlab chiqaruvchilar",
        "distributor": "distribyutorlar",
        "retail": "chakana savdo",
        "service": "xizmatlar",
    },
    "ru": {
        "manufacturer": "производители",
        "distributor": "дистрибьюторы",
        "retail": "розница",
        "service": "услуги",
    },
    "en": {
        "manufacturer": "manufacturers",
        "distributor": "distributors",
        "retail": "retailers",
        "service": "services",
    },
}


def _locale(code: str) -> str:
    c = (code or "uz").lower().split("_")[0]
    if c in {"ru", "rus"}:
        return "ru"
    if c in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


def _normalize_token(token: str) -> str:
    t = token.strip().lower()
    t = t.replace("ʻ", "'").replace("'", "'").replace("`", "'")
    return t


def _tokenize(query: str) -> list[str]:
    raw = re.findall(
        r"[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳʼ‘'\-]{2,}|\d{2,}",
        query or "",
        flags=re.UNICODE,
    )
    return [_normalize_token(t) for t in raw if _normalize_token(t)]


def _parse_price_bounds(query: str) -> tuple[Decimal | None, Decimal | None]:
    q = (query or "").lower()
    max_price: Decimal | None = None
    min_price: Decimal | None = None
    m = re.search(
        r"(?:under|below|max|upto|up to|до|less than|<)\s*\$?\s*(\d+(?:[.,]\d+)?)",
        q,
    )
    if m:
        max_price = Decimal(m.group(1).replace(",", "."))
    m2 = re.search(
        r"(?:over|above|min|from|от|>\s*)\s*\$?\s*(\d+(?:[.,]\d+)?)",
        q,
    )
    if m2:
        min_price = Decimal(m2.group(1).replace(",", "."))
    return min_price, max_price


def _parse_rules(query: str, locale: str) -> dict:
    tokens = _tokenize(query)
    country: str | None = None
    role: str | None = None
    category: str | None = None
    search_parts: list[str] = []
    topic_label: str | None = None
    verified_only = False
    sort: str | None = None
    price_hint: str | None = None

    for tok in tokens:
        if tok in {"verified", "tasdiqlangan", "проверенный", "factory-verified"}:
            verified_only = True
            continue
        if tok in _CHEAP_TOKENS:
            sort = "price_asc"
            price_hint = "cheap"
            continue
        if tok in _EXPENSIVE_TOKENS:
            sort = "price_desc"
            price_hint = "expensive"
            continue
        if country is None and tok in _COUNTRY_ALIASES:
            country = _COUNTRY_ALIASES[tok]
            continue
        if role is None and tok in _ROLE_ALIASES:
            role = _ROLE_ALIASES[tok]
            continue
        if tok in _TOPIC_ALIASES:
            cat, kw, labels = _TOPIC_ALIASES[tok]
            if category is None and cat in _VALID_CATEGORIES:
                category = cat
            if topic_label is None:
                topic_label = labels.get(locale) or labels["en"]
            if kw and kw not in search_parts:
                search_parts.append(kw)
            continue
        if tok in _STOPWORDS:
            continue
        if len(tok) >= 3 and tok not in search_parts:
            search_parts.append(tok)

    search = " ".join(search_parts[:4]).strip() or None
    if topic_label and category == "clothing_accessories" and (country or role):
        category = None
        if not search:
            search = "textile"

    min_price, max_price = _parse_price_bounds(query)
    if price_hint == "cheap" and max_price is None:
        max_price = Decimal("50")

    return {
        "country": country,
        "category": category,
        "business_role": role,
        "verified_only": verified_only,
        "search": search,
        "topic_label": topic_label,
        "sort": sort,
        "min_price": float(min_price) if min_price is not None else None,
        "max_price": float(max_price) if max_price is not None else None,
        "price_hint": price_hint,
    }


def _build_interpretation(parsed: dict, locale: str) -> str:
    country = parsed.get("country")
    role = parsed.get("business_role")
    topic = parsed.get("topic_label")
    search = (parsed.get("search") or "").strip()
    sort = parsed.get("sort")
    price_hint = parsed.get("price_hint")
    country_name = None
    if country:
        country_name = _COUNTRY_LABELS.get(locale, {}).get(country) or country

    role_label = None
    if role:
        role_label = _ROLE_LABELS.get(locale, {}).get(role) or role

    topic_part = topic or search
    cheap_prefix = {"uz": "Arzon ", "ru": "Недорогие ", "en": "Cheap "}.get(locale, "Cheap ")
    expensive_prefix = {"uz": "Premium ", "ru": "Премиум ", "en": "Premium "}.get(
        locale, "Premium "
    )
    prefix = ""
    if sort == "price_asc" or price_hint == "cheap":
        prefix = cheap_prefix
    elif sort == "price_desc" or price_hint == "expensive":
        prefix = expensive_prefix

    if locale == "ru":
        if country_name and topic_part and role_label:
            core = f"{country_name}: {topic_part} — {role_label}"
        elif country_name and role_label:
            core = f"{country_name}: {role_label}"
        elif country_name and topic_part:
            core = f"{country_name}: {topic_part}"
        elif topic_part and role_label:
            core = f"{topic_part} — {role_label}"
        else:
            core = topic_part or search or "Результаты поиска"
        return f"{prefix}{core}".strip()
    if locale == "en":
        if country_name and topic_part and role_label:
            core = f"{topic_part} {role_label} in {country_name}"
        elif country_name and role_label:
            core = f"{role_label} in {country_name}"
        elif country_name and topic_part:
            core = f"{topic_part} in {country_name}"
        elif topic_part and role_label:
            core = f"{topic_part} {role_label}"
        else:
            core = topic_part or search or "Search results"
        return f"{prefix}{core}".strip()

    if country_name and topic_part and role_label:
        core = f"{country_name}dagi {topic_part} {role_label}"
    elif country_name and role_label:
        core = f"{country_name}dagi {role_label}"
    elif country_name and topic_part:
        core = f"{country_name}dagi {topic_part}"
    elif topic_part and role_label:
        core = f"{topic_part} {role_label}"
    else:
        core = topic_part or search or "Qidiruv natijalari"
    return f"{prefix}{core}".strip()


async def _openai_parse(query: str, locale: str) -> dict:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key or not query.strip():
        return {}
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    system = (
        "You are AnyTrade Smart Search parser for a B2B marketplace. "
        "Parse the user query into marketplace filters. Reply ONLY JSON:\n"
        "{"
        '"country":"TR"|null,'
        '"category":"clothing_accessories|pottery|woodwork|jewelry|other"|null,'
        '"business_role":"manufacturer|distributor|retail|service"|null,'
        '"verified_only":false,'
        '"search":"keyword or null",'
        '"sort":"price_asc|price_desc|recommended|newest"|null,'
        '"min_price":number|null,'
        '"max_price":number|null,'
        '"topic_label":"short topic in user language",'
        '"interpretation":"one short human sentence of what we understood"'
        "}\n"
        "Rules:\n"
        "- country must be ISO-3166 alpha-2 when a country/region is mentioned.\n"
        "- 'factory' / 'manufacturer' / 'ishlab chiqaruvchi' → business_role=manufacturer.\n"
        "- 'Factory in Turkey' → country=TR, business_role=manufacturer.\n"
        "- textile / apparel / to'qimachilik → category clothing_accessories OR search=textile.\n"
        "- futbolka / t-shirt / футболка → search=futbolka, category clothing_accessories.\n"
        "- arzon / cheap / дешево → sort=price_asc; soft max_price≈50 if none given.\n"
        "- qimmat / expensive / premium → sort=price_desc.\n"
        "- Prefer structured filters over dumping the whole phrase into search.\n"
        "- interpretation examples: "
        "'Turkiyadagi to‘qimachilik ishlab chiqaruvchilari', "
        "'Arzon futbolka', 'Cheap t-shirts', 'Factories in Turkey'.\n"
        f"User UI locale hint: {locale}."
    )
    payload = {
        "model": model,
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": query.strip()},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=35.0) as client:
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
        return parsed if isinstance(parsed, dict) else {}
    except Exception as exc:
        logger.warning("smart_search openai failed: %s", exc)
        return {}


def _sanitize_ai(raw: dict, locale: str) -> dict:
    country = raw.get("country")
    cc = str(country).strip().upper() if country else None
    if cc and len(cc) != 2:
        cc = _COUNTRY_ALIASES.get(_normalize_token(str(country)))
    category = raw.get("category")
    cat = str(category).strip() if category else None
    if cat and cat not in _VALID_CATEGORIES:
        tok = _normalize_token(cat)
        if tok in _TOPIC_ALIASES:
            cat = _TOPIC_ALIASES[tok][0]
        else:
            cat = None
    role = raw.get("business_role")
    role_s = str(role).strip().lower() if role else None
    if role_s and role_s not in _VALID_ROLES:
        role_s = _ROLE_ALIASES.get(_normalize_token(role_s))
        if role_s not in _VALID_ROLES:
            role_s = None
    search = raw.get("search")
    search_s = str(search).strip() if search else None
    if search_s and len(search_s) > 80:
        search_s = search_s[:80]
    topic = raw.get("topic_label")
    topic_s = str(topic).strip() if topic else None
    sort_raw = raw.get("sort")
    sort_s = str(sort_raw).strip().lower() if sort_raw else None
    if sort_s and sort_s not in _VALID_SORTS:
        sort_s = None
    min_p = raw.get("min_price")
    max_p = raw.get("max_price")
    try:
        min_f = float(min_p) if min_p is not None else None
    except (TypeError, ValueError):
        min_f = None
    try:
        max_f = float(max_p) if max_p is not None else None
    except (TypeError, ValueError):
        max_f = None
    return {
        "country": cc,
        "category": cat,
        "business_role": role_s,
        "verified_only": bool(raw.get("verified_only")),
        "search": search_s or None,
        "topic_label": topic_s,
        "sort": sort_s,
        "min_price": min_f,
        "max_price": max_f,
        "interpretation": (str(raw.get("interpretation") or "").strip() or None),
    }


def apply_smart_keyword_filter(query, search: str | None):
    """Mahsulot + kompaniya kalit so‘zlari bo‘yicha kengaytirilgan qidiruv."""
    if not search or not search.strip():
        return query
    terms = [t for t in re.split(r"\s+", search.strip()) if len(t) >= 2][:4]
    if not terms:
        return query
    for term in terms:
        pattern = f"%{term}%"
        query = query.where(
            or_(
                Product.name.ilike(pattern),
                Product.short_description.ilike(pattern),
                Product.description.ilike(pattern),
                BusinessProfile.company_name.ilike(pattern),
                BusinessProfile.description.ilike(pattern),
                BusinessProfile.seo_text.ilike(pattern),
                cast(BusinessProfile.keywords, String).ilike(pattern),
            )
        )
    return query


async def parse_query(query: str, locale: str = "uz") -> dict:
    loc = _locale(locale)
    rules = _parse_rules(query, loc)
    ai = await _openai_parse(query, loc)
    generated_by = "rules"
    interpretation = None
    if ai:
        generated_by = "openai"
        sanitized = _sanitize_ai(ai, loc)
        for key in (
            "country",
            "category",
            "business_role",
            "search",
            "topic_label",
            "sort",
            "min_price",
            "max_price",
        ):
            if sanitized.get(key) is not None and sanitized.get(key) != "":
                rules[key] = sanitized[key]
        if sanitized.get("verified_only"):
            rules["verified_only"] = True
        interpretation = sanitized.get("interpretation")
    if not interpretation:
        interpretation = _build_interpretation(rules, loc)
    return {
        "parsed": {
            "country": rules.get("country"),
            "category": rules.get("category"),
            "business_role": rules.get("business_role"),
            "verified_only": bool(rules.get("verified_only")),
            "search": rules.get("search"),
            "sort": rules.get("sort"),
            "min_price": rules.get("min_price"),
            "max_price": rules.get("max_price"),
        },
        "interpretation": interpretation,
        "generated_by": generated_by,
        "topic_label": rules.get("topic_label"),
        "price_hint": rules.get("price_hint"),
    }


async def smart_search(
    db: AsyncSession,
    *,
    viewer: User,
    query: str,
    locale: str = "uz",
    page: int | None = None,
    limit: int | None = None,
) -> dict:
    q = (query or "").strip()
    meta = await parse_query(q, locale=locale)
    parsed = meta["parsed"]

    sort = (parsed.get("sort") or "recommended").strip().lower()
    if sort not in _VALID_SORTS:
        sort = "recommended"

    min_price = parsed.get("min_price")
    max_price = parsed.get("max_price")
    min_dec = Decimal(str(min_price)) if min_price is not None else None
    max_dec = Decimal(str(max_price)) if max_price is not None else None

    result = await products_service.list_products(
        db,
        viewer=viewer,
        search=None,
        category=parsed.get("category"),
        min_price=min_dec,
        max_price=max_dec,
        currency=None,
        seller_id=None,
        country=parsed.get("country"),
        business_role=parsed.get("business_role"),
        verified_only=bool(parsed.get("verified_only")),
        sort=sort,
        page=page,
        limit=limit or 40,
        smart_search=parsed.get("search"),
    )

    return {
        **result,
        "raw_query": q,
        "interpretation": meta["interpretation"],
        "parsed": parsed,
        "generated_by": meta["generated_by"],
    }
