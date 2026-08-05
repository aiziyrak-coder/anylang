"""Catalog multilingual fields — one source language → all trade languages."""

from __future__ import annotations

import json
import logging
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.models.product import Product
from app.models.user import BusinessProfile, User
from app.services.company_profile import PROFILE_I18N_LANGS, _locale_hint

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"


def pick_i18n(i18n: dict | None, fallback: str, lang: str | None) -> str:
    """Pick localized string; fallback to original."""
    code = _locale_hint(lang or "uz")
    mapping = i18n if isinstance(i18n, dict) else {}
    for key in (code, code[:2] if code else "", "en", "uz", "ru"):
        if not key:
            continue
        val = mapping.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return (fallback or "").strip()


def _clean_map(raw: dict[str, Any] | None, *, max_len: int) -> dict[str, str]:
    out: dict[str, str] = {}
    if not isinstance(raw, dict):
        return out
    for code in PROFILE_I18N_LANGS:
        val = str(raw.get(code) or "").strip()
        if val:
            out[code] = val[:max_len]
    return out


async def _openai_json(system: str, user: str) -> dict[str, Any]:
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        return {}
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    payload = {
        "model": model,
        "temperature": 0.2,
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
    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(OPENAI_CHAT_URL, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
    content = (
        ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
    ).strip()
    parsed = json.loads(content) if content else {}
    return parsed if isinstance(parsed, dict) else {}


async def generate_product_i18n(
    *,
    name: str,
    short_description: str,
    description: str,
    source_lang: str = "uz",
) -> dict[str, dict[str, str]]:
    """Return name_i18n / short_description_i18n / description_i18n maps."""
    loc = _locale_hint(source_lang)
    name = (name or "").strip()
    short = (short_description or "").strip()
    desc = (description or "").strip()
    if not name and not short and not desc:
        return {
            "name_i18n": {},
            "short_description_i18n": {},
            "description_i18n": {},
        }

    seed_name = {loc: name} if name else {}
    seed_short = {loc: short} if short else {}
    seed_desc = {loc: desc} if desc else {}

    settings = get_settings()
    if not (settings.openai_api_key or "").strip():
        # Dev / no key: at least store source language
        return {
            "name_i18n": seed_name,
            "short_description_i18n": seed_short,
            "description_i18n": seed_desc,
        }

    codes = ", ".join(PROFILE_I18N_LANGS.keys())
    system = (
        "You are AnyLang marketplace catalog translator for B2B product listings.\n"
        "Return JSON only with keys:\n"
        "- name_i18n: object language_code -> product name\n"
        "- short_description_i18n: object language_code -> short blurb\n"
        "- description_i18n: object language_code -> full description\n"
        "Rules:\n"
        f"- Source language: {loc}\n"
        f"- Include ALL codes: {codes}\n"
        "- Keep brand names / model codes / units unchanged when possible.\n"
        "- Do not invent certifications, prices, or specs not in the source.\n"
        "- Empty source fields stay empty strings in all languages.\n"
        "- Natural marketplace tone, no markdown.\n"
    )
    user = (
        f"source_lang={loc}\n"
        f"name={name}\n"
        f"short_description={short}\n"
        f"description={desc[:3000]}"
    )
    try:
        parsed = await _openai_json(system, user)
    except Exception as exc:
        logger.warning("product i18n failed: %s", exc)
        return {
            "name_i18n": seed_name,
            "short_description_i18n": seed_short,
            "description_i18n": seed_desc,
        }

    name_i18n = _clean_map(parsed.get("name_i18n"), max_len=100)
    short_i18n = _clean_map(parsed.get("short_description_i18n"), max_len=120)
    desc_i18n = _clean_map(parsed.get("description_i18n"), max_len=4000)
    if name:
        name_i18n.setdefault(loc, name)
        for code in PROFILE_I18N_LANGS:
            name_i18n.setdefault(code, name)
    if short:
        short_i18n.setdefault(loc, short)
        for code in PROFILE_I18N_LANGS:
            short_i18n.setdefault(code, short)
    if desc:
        desc_i18n.setdefault(loc, desc)
        for code in PROFILE_I18N_LANGS:
            desc_i18n.setdefault(code, desc)
    return {
        "name_i18n": name_i18n,
        "short_description_i18n": short_i18n,
        "description_i18n": desc_i18n,
    }


async def generate_business_description_i18n(
    *,
    company_name: str,
    description: str,
    bio: str = "",
    source_lang: str = "uz",
) -> dict[str, str]:
    loc = _locale_hint(source_lang)
    text = (description or bio or "").strip()
    if not text:
        return {}
    settings = get_settings()
    if not (settings.openai_api_key or "").strip():
        return {loc: text[:4000]}

    codes = ", ".join(PROFILE_I18N_LANGS.keys())
    system = (
        "You are AnyLang B2B company profile translator.\n"
        "Return JSON only: {\"description_i18n\": {lang_code: text}}.\n"
        f"Include ALL codes: {codes}. Source language: {loc}.\n"
        "Keep facts; do not invent awards/certs. No markdown.\n"
    )
    user = f"company={company_name or '-'}\nsource_lang={loc}\ntext={text[:3500]}"
    try:
        parsed = await _openai_json(system, user)
    except Exception as exc:
        logger.warning("business i18n failed: %s", exc)
        return {loc: text[:4000]}
    out = _clean_map(parsed.get("description_i18n"), max_len=4000)
    out.setdefault(loc, text[:4000])
    for code in PROFILE_I18N_LANGS:
        out.setdefault(code, text[:4000])
    return out


async def apply_product_i18n(
    db: AsyncSession,
    product_id: int,
    *,
    source_lang: str | None = None,
) -> bool:
    product = (
        await db.execute(select(Product).where(Product.id == product_id))
    ).scalar_one_or_none()
    if product is None:
        return False
    src = source_lang or getattr(product, "source_lang", None) or "uz"
    data = await generate_product_i18n(
        name=product.name,
        short_description=product.short_description or "",
        description=product.description or "",
        source_lang=src,
    )
    product.name_i18n = data["name_i18n"]
    product.short_description_i18n = data["short_description_i18n"]
    product.description_i18n = data["description_i18n"]
    product.source_lang = _locale_hint(src)
    await db.commit()
    return True


async def apply_business_i18n(
    db: AsyncSession,
    user_id: int,
    *,
    source_lang: str | None = None,
) -> bool:
    user = (
        await db.execute(
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.business))
        )
    ).scalar_one_or_none()
    if user is None or user.business is None:
        return False
    biz: BusinessProfile = user.business
    src = source_lang or "uz"
    mapping = await generate_business_description_i18n(
        company_name=biz.company_name or "",
        description=biz.description or "",
        bio=biz.bio or "",
        source_lang=src,
    )
    if mapping:
        biz.description_i18n = mapping
        if not (biz.description or "").strip() and mapping.get(_locale_hint(src)):
            biz.description = mapping[_locale_hint(src)]
        await db.commit()
        return True
    return False


async def enqueue_catalog_translate(
    *,
    kind: str,
    entity_id: int,
    source_lang: str | None = None,
    defer_seconds: int = 0,
) -> None:
    """Enqueue ARQ job; never raise to callers."""
    try:
        from app.services.maintenance_ops import get_feature_flags_cached

        flags = await get_feature_flags_cached()
        if flags.get("translate_enabled") is False:
            return
    except Exception:
        pass
    try:
        from datetime import timedelta

        from arq import create_pool
        from arq.connections import RedisSettings

        from app.core.config import get_settings

        pool = await create_pool(RedisSettings.from_dsn(get_settings().redis_url))
        kwargs: dict[str, Any] = {}
        if defer_seconds > 0:
            kwargs["_defer_by"] = timedelta(seconds=defer_seconds)
        await pool.enqueue_job(
            "translate_catalog_job",
            kind,
            entity_id,
            source_lang or "uz",
            **kwargs,
        )
        await pool.aclose()
    except Exception as exc:
        logger.warning(
            "enqueue catalog translate failed kind=%s id=%s: %s", kind, entity_id, exc
        )
