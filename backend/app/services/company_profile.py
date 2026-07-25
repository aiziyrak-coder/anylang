"""AI Company Profile — generate professional description, SEO, keywords, i18n."""

from __future__ import annotations

import json
import logging

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

# 20 trade-relevant languages (code -> native label)
PROFILE_I18N_LANGS: dict[str, str] = {
    "uz": "Oʻzbekcha",
    "ru": "Русский",
    "en": "English",
    "tr": "Türkçe",
    "zh": "中文",
    "ar": "العربية",
    "de": "Deutsch",
    "fr": "Français",
    "es": "Español",
    "it": "Italiano",
    "pt": "Português",
    "hi": "हिन्दी",
    "ko": "한국어",
    "ja": "日本語",
    "pl": "Polski",
    "uk": "Українська",
    "kk": "Қазақша",
    "fa": "فارسی",
    "id": "Bahasa Indonesia",
    "ms": "Bahasa Melayu",
}


def _locale_hint(locale: str) -> str:
    code = (locale or "uz").lower().split("_")[0]
    if code in {"ru", "rus"}:
        return "ru"
    if code in {"en", "us", "gb", "eng"}:
        return "en"
    if code in PROFILE_I18N_LANGS:
        return code
    return "uz"


def _fallback(
    *,
    prompt: str,
    company_name: str,
    locale: str,
) -> dict:
    loc = _locale_hint(locale)
    name = (company_name or "").strip() or "Company"
    seed = (prompt or "").strip()
    if loc == "ru":
        description = (
            f"{name} — профессиональный B2B партнёр. {seed} "
            "Мы предлагаем стабильное качество, гибкий MOQ и экспортные поставки."
        )
        seo = (
            f"{name}: производство и поставка. {seed} "
            "Запросите каталог, цену и сроки поставки на AnyLang."
        )
    elif loc == "en":
        description = (
            f"{name} is a professional B2B partner. {seed} "
            "We focus on consistent quality, flexible MOQ and export-ready delivery."
        )
        seo = (
            f"{name}: manufacturing & supply. {seed} "
            "Request catalog, pricing and lead time on AnyLang."
        )
    else:
        description = (
            f"{name} — professional B2B hamkor. {seed} "
            "Sifat, moslashuvchan MOQ va eksport yetkazib berishga e’tibor beramiz."
        )
        seo = (
            f"{name}: ishlab chiqarish va yetkazib berish. {seed} "
            "AnyLang orqali katalog, narx va muddat so‘rang."
        )

    keywords = [
        w.strip(".,;:!?\"'()[]")
        for w in seed.replace(",", " ").split()
        if len(w.strip(".,;:!?\"'()[]")) >= 3
    ][:8]
    if not keywords:
        keywords = ["B2B", "export", "manufacturer", "wholesale", "OEM"]

    translations = {code: description for code in PROFILE_I18N_LANGS}
    translations[loc] = description
    return {
        "description": description.strip(),
        "seo_text": seo.strip(),
        "keywords": keywords,
        "translations": translations,
        "languages": [
            {"code": code, "name": name_} for code, name_ in PROFILE_I18N_LANGS.items()
        ],
    }


async def generate_company_profile(
    *,
    prompt: str,
    company_name: str = "",
    country: str = "",
    business_role: str = "",
    locale: str = "uz",
) -> dict:
    text = (prompt or "").strip()
    if len(text) < 8:
        raise AppError(
            message="Kompaniya haqida qisqa matn yozing",
            error_code="AI_PROFILE_PROMPT_SHORT",
            status_code=400,
        )

    loc = _locale_hint(locale)
    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        if settings.is_production:
            raise AppError(
                message="AI profil hozircha mavjud emas",
                error_code="AI_PROFILE_UNAVAILABLE",
                status_code=503,
            )
        return _fallback(prompt=text, company_name=company_name, locale=loc)

    lang_list = ", ".join(
        f"{code} ({name})" for code, name in PROFILE_I18N_LANGS.items()
    )
    system = (
        "You are AnyLang AI Company Profile writer for B2B marketplace listings.\n"
        "Return JSON only with keys:\n"
        "- description (string): professional company about text in the PRIMARY language\n"
        "- seo_text (string): SEO-oriented marketplace blurb in PRIMARY language (120-220 words max)\n"
        "- keywords (string array): 8-15 short SEO/trade keywords\n"
        "- translations (object): map of language_code -> professional description\n"
        "Rules:\n"
        f"- PRIMARY language code: {loc}\n"
        f"- translations MUST include ALL of these codes: {', '.join(PROFILE_I18N_LANGS)}\n"
        f"  Labels for reference: {lang_list}\n"
        "- Do not invent fake certifications, awards, years, or exact prices.\n"
        "- Keep claims general and trustworthy based on the user prompt.\n"
        "- No markdown, no hashtags in description/seo.\n"
        "- keywords: lowercase or Title Case short phrases, no duplicates.\n"
    )
    user = (
        f"Company name: {company_name or '-'}\n"
        f"Country: {country or '-'}\n"
        f"Business role: {business_role or '-'}\n"
        f"Primary language: {loc}\n"
        f"Buyer/seller prompt:\n{text[:2000]}"
    )

    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    payload = {
        "model": model,
        "temperature": 0.45,
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
        async with httpx.AsyncClient(timeout=70.0) as client:
            response = await client.post(
                OPENAI_CHAT_URL, headers=headers, json=payload
            )
            response.raise_for_status()
            data = response.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content")
            or ""
        ).strip()
        parsed = json.loads(content) if content else {}
        if not isinstance(parsed, dict):
            parsed = {}
    except Exception as exc:
        logger.warning("ai company profile failed: %s", exc)
        if settings.is_production:
            raise AppError(
                message="AI profil yaratilmadi. Keyinroq urinib ko‘ring",
                error_code="AI_PROFILE_FAILED",
                status_code=502,
            ) from exc
        return _fallback(prompt=text, company_name=company_name, locale=loc)

    description = str(parsed.get("description") or "").strip()
    seo_text = str(parsed.get("seo_text") or "").strip()
    raw_kw = parsed.get("keywords") or []
    keywords: list[str] = []
    seen: set[str] = set()
    if isinstance(raw_kw, list):
        for item in raw_kw:
            k = " ".join(str(item or "").split()).strip()
            if not k:
                continue
            key = k.lower()
            if key in seen:
                continue
            seen.add(key)
            keywords.append(k[:48])
            if len(keywords) >= 15:
                break

    raw_tr = parsed.get("translations") or {}
    translations: dict[str, str] = {}
    if isinstance(raw_tr, dict):
        for code in PROFILE_I18N_LANGS:
            val = str(raw_tr.get(code) or "").strip()
            if val:
                translations[code] = val[:4000]

    if not description:
        description = str(translations.get(loc) or next(iter(translations.values()), "")).strip()
    if not description:
        return _fallback(prompt=text, company_name=company_name, locale=loc)
    if loc not in translations:
        translations[loc] = description
    for code in PROFILE_I18N_LANGS:
        translations.setdefault(code, description)
    if not seo_text:
        seo_text = description[:400]
    if not keywords:
        keywords = ["B2B", "export", "wholesale"]

    return {
        "description": description[:4000],
        "seo_text": seo_text[:4000],
        "keywords": keywords,
        "translations": translations,
        "languages": [
            {"code": code, "name": name} for code, name in PROFILE_I18N_LANGS.items()
        ],
    }
