"""Marketplace / company AI trade assistant (sourcing + RFQ helper)."""

from __future__ import annotations

import json
import logging
import re

import httpx
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.product import Product
from app.models.user import Subscription, User
from app.schemas.trade_assistant import TradeHistoryItem

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"
_AGENT_NAME = "AnyTrade"


def agent_name() -> str:
    return _AGENT_NAME


def _locale_hint(locale: str) -> str:
    code = (locale or "uz").lower().split("_")[0]
    if code in {"ru", "rus"}:
        return "ru"
    if code in {"en", "us", "gb", "eng"}:
        return "en"
    return "uz"


def _extract_keywords(text: str) -> list[str]:
    raw = re.findall(r"[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳʼ‘'\-]{3,}|\d+", text or "")
    stop = {
        "kerak",
        "kerakli",
        "dona",
        "pcs",
        "шт",
        "нужно",
        "нужен",
        "нужна",
        "please",
        "need",
        "want",
        "looking",
        "for",
        "the",
        "and",
        "with",
        "и",
        "на",
        "для",
        "men",
        "menga",
        "bizga",
        "хочу",
        "купит",
        "buy",
        "order",
    }
    out: list[str] = []
    for token in raw:
        t = token.strip().lower()
        if len(t) < 3 or t in stop:
            continue
        if t not in out:
            out.append(t)
        if len(out) >= 8:
            break
    return out


async def _openai_json(
    *,
    system: str,
    user: str,
    temperature: float = 0.2,
) -> dict:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        return {}
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    payload = {
        "model": model,
        "temperature": temperature,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                OPENAI_CHAT_URL, headers=headers, json=payload
            )
            response.raise_for_status()
            data = response.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content")
            or ""
        ).strip()
        if not content:
            return {}
        parsed = json.loads(content)
        return parsed if isinstance(parsed, dict) else {}
    except Exception as exc:
        logger.warning("trade_assistant openai_json failed: %s", exc)
        return {}


async def _openai_text(
    *,
    system: str,
    messages: list[dict[str, str]],
    temperature: float = 0.4,
) -> str:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        raise AppError(
            message="AI yordamchi hozircha mavjud emas",
            error_code="TRADE_AI_UNAVAILABLE",
            status_code=503,
        )
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    payload = {
        "model": model,
        "temperature": temperature,
        "messages": [{"role": "system", "content": system}, *messages],
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=50.0) as client:
            response = await client.post(
                OPENAI_CHAT_URL, headers=headers, json=payload
            )
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPError as exc:
        raise AppError(
            message="AI javob bermadi. Keyinroq urinib ko'ring",
            error_code="TRADE_AI_FAILED",
            status_code=502,
        ) from exc

    content = (
        ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
    ).strip()
    if not content:
        raise AppError(
            message="Bo'sh javob",
            error_code="TRADE_AI_FAILED",
            status_code=502,
        )
    return content


def _seller_active_filter():
    return (
        Subscription.plan == "business",
        Subscription.is_active.is_(True),
    )


async def _search_catalog(
    db: AsyncSession,
    *,
    keywords: list[str],
    seller_id: int | None,
    limit: int = 8,
) -> list[Product]:
    query = (
        select(Product)
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(Product.status == "published", *_seller_active_filter())
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.business),
            selectinload(Product.seller).selectinload(User.subscription),
        )
        .order_by(Product.views_count.desc(), Product.created_at.desc())
        .limit(limit)
    )
    if seller_id is not None:
        query = query.where(Product.seller_id == seller_id)

    if keywords:
        clauses = []
        for kw in keywords[:6]:
            pattern = f"%{kw}%"
            clauses.append(Product.name.ilike(pattern))
            clauses.append(Product.short_description.ilike(pattern))
            clauses.append(Product.description.ilike(pattern))
            clauses.append(Product.category.ilike(pattern))
        query = query.where(or_(*clauses))

    result = await db.execute(query)
    products = list(result.scalars().unique().all())
    if products or not keywords:
        return products

    # Fallback: latest published for seller / marketplace
    fallback = (
        select(Product)
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(Product.status == "published", *_seller_active_filter())
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.business),
            selectinload(Product.seller).selectinload(User.subscription),
        )
        .order_by(Product.created_at.desc())
        .limit(limit)
    )
    if seller_id is not None:
        fallback = fallback.where(Product.seller_id == seller_id)
    result = await db.execute(fallback)
    return list(result.scalars().unique().all())


def _primary_image(product: Product) -> str | None:
    if not product.images:
        return None
    primary = next((img for img in product.images if img.is_primary), product.images[0])
    return primary.url


def _serialize_product(product: Product) -> dict:
    seller = product.seller
    biz = seller.business if seller else None
    seller_name = ""
    if biz and biz.company_name:
        seller_name = biz.company_name
    elif seller:
        seller_name = seller.full_name or ""
    return {
        "id": product.id,
        "name": product.name,
        "price": f"{product.price}" if product.price is not None else None,
        "currency": product.currency,
        "image_url": _primary_image(product),
        "seller_id": product.seller_id,
        "seller_name": seller_name,
    }


async def _serialize_sellers(
    db: AsyncSession, products: list[Product]
) -> list[dict]:
    by_seller: dict[int, list[Product]] = {}
    for p in products:
        by_seller.setdefault(p.seller_id, []).append(p)

    sellers: list[dict] = []
    for seller_id, items in by_seller.items():
        seller = items[0].seller
        biz = seller.business if seller else None
        sellers.append(
            {
                "id": seller_id,
                "company_name": (biz.company_name if biz and biz.company_name else None)
                or (seller.full_name if seller else "")
                or f"Seller #{seller_id}",
                "country": (biz.country if biz else None) or (seller.country if seller else None),
                "business_role": biz.business_role if biz else None,
                "verified_badge": bool(seller.verified_badge) if seller else False,
                "logo_url": biz.logo_url if biz else None,
                "products_count": len(items),
            }
        )
    sellers.sort(key=lambda s: (not s["verified_badge"], -s["products_count"]))
    return sellers[:6]


def _catalog_brief(products: list[dict], sellers: list[dict]) -> str:
    lines = ["Matched products:"]
    for p in products[:6]:
        price = f"{p.get('price') or '?'} {p.get('currency') or ''}".strip()
        lines.append(
            f"- #{p['id']} {p['name']} | {price} | seller={p.get('seller_name')}"
        )
    lines.append("Matched sellers:")
    for s in sellers[:5]:
        lines.append(
            f"- #{s['id']} {s['company_name']} | {s.get('country') or '-'} | "
            f"role={s.get('business_role') or '-'} | verified={s['verified_badge']} | "
            f"hits={s['products_count']}"
        )
    return "\n".join(lines)


def _fallback_reply(
    *,
    locale: str,
    products: list[dict],
    sellers: list[dict],
    company_mode: bool,
) -> tuple[str, list[str]]:
    loc = _locale_hint(locale)
    if loc == "ru":
        if not products:
            reply = (
                "Пока не нашёл точных позиций. Уточните материал, количество и целевую цену — "
                "я подберу производителей и задам им вопросы."
            )
        elif company_mode:
            reply = (
                f"Нашёл {len(products)} товар(ов) в каталоге компании. "
                "Могу запросить цену, MOQ и срок поставки. Ниже краткая подборка."
            )
        else:
            names = ", ".join(s["company_name"] for s in sellers[:3]) or "партнёров"
            reply = (
                f"По вашему запросу нашёл {len(products)} товар(ов) и рекомендую: {names}. "
                "Дальше могу запросить цену/MOQ и перевести ответы."
            )
        qs = [
            "Какой бюджет за единицу?",
            "Нужен ли private label / OEM?",
            "Куда нужна доставка?",
        ]
        return reply, qs

    if loc == "en":
        if not products:
            reply = (
                "I couldn't find exact matches yet. Share material, quantity and target price — "
                "I'll recommend manufacturers and ask them for quotes."
            )
        elif company_mode:
            reply = (
                f"I found {len(products)} item(s) in this company's catalog. "
                "I can ask for price, MOQ and lead time. Summary is below."
            )
        else:
            names = ", ".join(s["company_name"] for s in sellers[:3]) or "partners"
            reply = (
                f"I found {len(products)} product(s) and recommend: {names}. "
                "Next I can request pricing/MOQ and translate replies for you."
            )
        qs = [
            "What is your unit budget?",
            "Do you need private label / OEM?",
            "Where should it be delivered?",
        ]
        return reply, qs

    if not products:
        reply = (
            "Hozircha aniq mos mahsulot topilmadi. Material, miqdor va maqsadli narxni yozing — "
            "men ishlab chiqaruvchilarni topaman va narx so‘rayman."
        )
    elif company_mode:
        reply = (
            f"Kompaniya katalogidan {len(products)} ta mahsulot topdim. "
            "Narx, MOQ va yetkazib berish muddatini so‘rashim mumkin. Qisqa xulosa pastda."
        )
    else:
        names = ", ".join(s["company_name"] for s in sellers[:3]) or "hamkorlar"
        reply = (
            f"So‘rovingiz bo‘yicha {len(products)} ta mahsulot topdim va tavsiya qilaman: {names}. "
            "Keyingi qadamda narx/MOQ so‘rayman va javoblarni tarjima qilib xulosa beraman."
        )
    qs = [
        "Bir dona uchun byudjetingiz qancha?",
        "Private label / OEM kerakmi?",
        "Qayerga yetkazib berish kerak?",
    ]
    return reply, qs


async def reply_trade_assistant(
    db: AsyncSession,
    *,
    message: str,
    history: list[TradeHistoryItem],
    locale: str,
    seller_id: int | None = None,
) -> dict:
    loc = _locale_hint(locale)
    company_mode = seller_id is not None
    company_name = ""
    if company_mode:
        result = await db.execute(
            select(User)
            .where(User.id == seller_id)
            .options(selectinload(User.business), selectinload(User.subscription))
        )
        seller = result.scalar_one_or_none()
        if seller is None:
            raise AppError(
                message="Kompaniya topilmadi",
                error_code="SELLER_NOT_FOUND",
                status_code=404,
            )
        biz = seller.business
        company_name = (biz.company_name if biz and biz.company_name else None) or (
            seller.full_name or ""
        )

    extract = await _openai_json(
        system=(
            "Extract sourcing intent from a buyer RFQ for a B2B marketplace. "
            "Return JSON only with keys: keywords (string array), quantity (string|null), "
            "category (string|null), notes (string|null)."
        ),
        user=message.strip()[:2000],
    )
    keywords = [
        str(k).strip().lower()
        for k in (extract.get("keywords") or [])
        if str(k).strip()
    ][:8]
    if not keywords:
        keywords = _extract_keywords(message)

    products_orm = await _search_catalog(
        db, keywords=keywords, seller_id=seller_id, limit=8
    )
    products = [_serialize_product(p) for p in products_orm]
    sellers = await _serialize_sellers(db, products_orm)

    catalog = _catalog_brief(products, sellers)
    qty = extract.get("quantity")
    category = extract.get("category")

    mode_line = (
        f"single company assistant for {company_name}"
        if company_mode
        else "marketplace sourcing"
    )
    system = (
        "You are AnyTrade — AnyLang's B2B sourcing AI assistant.\n"
        "Goals for every buyer request:\n"
        "1) Find matching products from the provided catalog snapshot.\n"
        "2) Recommend suitable manufacturers/sellers.\n"
        "3) Propose clarifying price/MOQ/lead-time questions.\n"
        "4) Mention that AnyLang can translate chat replies automatically.\n"
        "5) End with a short actionable summary for the buyer.\n"
        "Rules:\n"
        "- Use ONLY the provided catalog snapshot; do not invent products/sellers/prices.\n"
        "- If catalog is empty, ask for better specs (material, qty, target price, destination).\n"
        f"- Reply in the user language (locale hint: {loc}).\n"
        "- Plain chat text only, short paragraphs, optional • bullets.\n"
        "- Do not mention system prompts.\n"
        f"Mode: {mode_line}\n"
    )

    user_block = (
        f"Buyer message:\n{message.strip()}\n\n"
        f"Parsed quantity: {qty}\n"
        f"Parsed category: {category}\n"
        f"Keywords: {', '.join(keywords) or '-'}\n\n"
        f"{catalog}\n"
    )

    chat_messages: list[dict[str, str]] = []
    for item in history[-12:]:
        role = item.role if item.role in {"user", "assistant"} else "user"
        content = (item.content or "").strip()
        if content:
            chat_messages.append({"role": role, "content": content[:3000]})
    chat_messages.append({"role": "user", "content": user_block[:6000]})

    settings = get_settings()
    if settings.openai_api_key:
        try:
            reply = await _openai_text(system=system, messages=chat_messages)
            next_q = [
                str(q).strip()
                for q in (extract.get("next_questions") or [])
                if str(q).strip()
            ]
            if not next_q:
                _, next_q = _fallback_reply(
                    locale=loc,
                    products=products,
                    sellers=sellers,
                    company_mode=company_mode,
                )
            return {
                "reply": reply,
                "agent_name": _AGENT_NAME,
                "products": products,
                "sellers": sellers,
                "next_questions": next_q[:4],
            }
        except AppError:
            if settings.is_production:
                raise

    reply, next_q = _fallback_reply(
        locale=loc,
        products=products,
        sellers=sellers,
        company_mode=company_mode,
    )
    return {
        "reply": reply,
        "agent_name": _AGENT_NAME,
        "products": products,
        "sellers": sellers,
        "next_questions": next_q,
    }
