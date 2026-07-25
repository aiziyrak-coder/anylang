import logging
import json
import re

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_LANG_NAMES = {
    "uz": "Uzbek (Latin script)",
    "ru": "Russian",
    "en": "English",
    "tr": "Turkish",
    "kk": "Kazakh",
    "ky": "Kyrgyz",
    "tg": "Tajik",
    "az": "Azerbaijani",
    "tk": "Turkmen",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "pt": "Portuguese",
    "it": "Italian",
    "pl": "Polish",
    "uk": "Ukrainian",
    "nl": "Dutch",
    "sv": "Swedish",
    "no": "Norwegian",
    "da": "Danish",
    "fi": "Finnish",
    "el": "Greek",
    "cs": "Czech",
    "sk": "Slovak",
    "ro": "Romanian",
    "hu": "Hungarian",
    "bg": "Bulgarian",
    "sr": "Serbian",
    "hr": "Croatian",
    "bs": "Bosnian",
    "ar": "Arabic",
    "fa": "Persian (Farsi)",
    "he": "Hebrew",
    "ka": "Georgian",
    "hy": "Armenian",
    "zh": "Chinese (Simplified)",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi",
    "bn": "Bengali",
    "ur": "Urdu",
    "pa": "Punjabi",
    "ta": "Tamil",
    "te": "Telugu",
    "mr": "Marathi",
    "gu": "Gujarati",
    "kn": "Kannada",
    "ml": "Malayalam",
    "si": "Sinhala",
    "ne": "Nepali",
    "th": "Thai",
    "vi": "Vietnamese",
    "id": "Indonesian",
    "ms": "Malay",
    "tl": "Filipino (Tagalog)",
    "my": "Burmese",
    "km": "Khmer",
    "sw": "Swahili",
    "am": "Amharic",
    "ha": "Hausa",
    "yo": "Yoruba",
}

# UI / locale leftovers → ISO 639-1 used by translation + DB matching.
_LANG_ALIASES = {
    "us": "en",
    "gb": "en",
    "eng": "en",
    "ua": "uk",
}

_LANG_QUALITY = {
    "uz": (
        "Uzbek: use modern Latin orthography (o‘, g‘, sh, ch, ng). "
        "Correct case endings and verb agreement. No Russian word-order calques. "
        "Natural spoken Uzbek for chat; never leave misspellings."
    ),
    "ru": (
        "Russian: perfect cases, gender/number agreement, verb aspect, and punctuation. "
        "Natural chat Russian; no literal calques from other languages."
    ),
    "en": (
        "English: correct articles (a/an/the), verb tense/agreement, prepositions, "
        "and spelling (US or consistent). Natural chat English; no broken syntax."
    ),
    "tr": (
        "Turkish: correct agglutination and vowel harmony; natural chat Turkish."
    ),
}

TRANSLATION_DOMAINS = (
    "general",
    "medical",
    "legal",
    "textile",
    "it",
    "construction",
)

_DOMAIN_HINTS = {
    "medical": (
        "Domain: MEDICAL / healthcare.\n"
        "Use precise clinical and pharmaceutical terminology (diagnosis, dosage, "
        "contraindications, lab markers, anatomy). Never invent drug names or dosages. "
        "Keep Latin/international drug and condition names correct when standard. "
        "Prefer clinician-grade wording over casual paraphrases."
    ),
    "legal": (
        "Domain: LEGAL / contracts.\n"
        "Preserve legal force of terms: party, obligation, liability, indemnity, "
        "jurisdiction, force majeure, termination, governing law. "
        "Do not soften or invent clauses. Keep defined terms consistent."
    ),
    "textile": (
        "Domain: TEXTILE / apparel manufacturing.\n"
        "Use industry terms correctly: GSM, yarn count, MOQ, OEM/ODM, greige, "
        "combed/carded, knit/woven, dyeing, finishing, fabric composition (%), "
        "lead time, packing. Keep units and specs exact."
    ),
    "it": (
        "Domain: IT / software.\n"
        "Preserve technical tokens: API, SDK, HTTP, JSON, CI/CD, repo, deploy, "
        "latency, auth/OAuth, DB schemas, error codes. Do not translate code "
        "identifiers, file paths, or command names."
    ),
    "construction": (
        "Domain: CONSTRUCTION / building materials.\n"
        "Use correct terms: foundation, rebar, concrete grade, formwork, "
        "load-bearing, HVAC, finishing, BOM, site, tender. Keep measurements "
        "and standards (MPa, m², ГОСТ/ISO codes) exact."
    ),
    "general": (
        "Domain: GENERAL chat / trade.\n"
        "Natural messaging tone; if specialized terms appear, translate them "
        "with the correct professional meaning for that field."
    ),
}

_DOMAIN_KEYWORDS: dict[str, tuple[str, ...]] = {
    "medical": (
        "patient", "diagnosis", "dosage", "clinic", "hospital", "symptom", "prescription",
        "bemor", "dori", "shifokor", "klinika", "tashxis", "davolash",
        "пациент", "диагноз", "доза", "клиника", "врач", "лечение", "симптом",
    ),
    "legal": (
        "contract", "clause", "liability", "indemnity", "jurisdiction", "lawsuit",
        "shartnoma", "band", "javobgarlik", "sud", "advokat", "huquq",
        "договор", "пункт", "ответственность", "юрисдикция", "иск", "адвокат",
    ),
    "textile": (
        "fabric", "cotton", "polyester", "gsm", "yarn", "knit", "woven", "moq", "oem",
        "paxta", "mato", "ip", "tikuv", "bo‘yoq", "futbolka",
        "ткань", "хлопок", "пряжа", "трикотаж", "окраска", "партия",
    ),
    "it": (
        "api", "sdk", "server", "backend", "frontend", "database", "deploy", "bug",
        "endpoint", "json", "oauth", "latency", "repo", "commit", "kubernetes",
        "сервер", "баг", "деплой", "база данных",
    ),
    "construction": (
        "concrete", "rebar", "foundation", "cement", "brick", "scaffold", "hvac",
        "beton", "armatura", "poydevor", "tsement", "g‘isht", "qurilish",
        "бетон", "арматура", "фундамент", "цемент", "стройка", "опалубка",
    ),
}


def normalize_translation_domain(code: str | None) -> str:
    raw = (code or "general").strip().lower().replace("-", "_")
    aliases = {
        "auto": "general",
        "default": "general",
        "health": "medical",
        "healthcare": "medical",
        "medicine": "medical",
        "law": "legal",
        "apparel": "textile",
        "fashion": "textile",
        "tech": "it",
        "software": "it",
        "building": "construction",
        "build": "construction",
    }
    raw = aliases.get(raw, raw)
    return raw if raw in TRANSLATION_DOMAINS else "general"


def detect_translation_domain(text: str) -> str:
    """Matndan sohani taxminiy aniqlash (kalit so‘zlar)."""
    blob = (text or "").lower()
    if not blob.strip():
        return "general"
    scores: dict[str, int] = {d: 0 for d in _DOMAIN_KEYWORDS}
    for domain, words in _DOMAIN_KEYWORDS.items():
        for w in words:
            if w in blob:
                scores[domain] += 1
    best = max(scores.items(), key=lambda kv: kv[1])
    if best[1] <= 0:
        return "general"
    return best[0]


def resolve_translation_domain(
    text: str,
    *,
    preferred: str | None = None,
    peers_preferred: list[str] | None = None,
) -> str:
    """
    Prefer explicit non-general preference; else peer consensus; else auto-detect.
    """
    pref = normalize_translation_domain(preferred)
    if pref != "general":
        return pref
    if peers_preferred:
        non_general = {
            normalize_translation_domain(p)
            for p in peers_preferred
            if normalize_translation_domain(p) != "general"
        }
        if len(non_general) == 1:
            return next(iter(non_general))
    return detect_translation_domain(text)


def _normalize_lang(code: str | None) -> str:
    raw = (code or "").strip().split("_")[0].split("-")[0].lower()
    if not raw:
        return "uz"
    return _LANG_ALIASES.get(raw, raw)


def user_preferred_lang(user) -> str:
    """Tarjima maqsad tili: ona tili (native); yo'q bo'lsa app tili."""
    native = getattr(user, "native_language", None)
    app = getattr(user, "app_language", None)
    return _normalize_lang(native or app or "uz")


_URL_TOKEN_RE = re.compile(
    r"(https?://[^\s<>\"']+|anylang://[^\s<>\"']+)",
    re.IGNORECASE,
)


def _is_url_only_message(text: str) -> bool:
    stripped = (text or "").strip()
    if not stripped:
        return True
    parts = stripped.split()
    return bool(parts) and all(_URL_TOKEN_RE.fullmatch(p) for p in parts)


def _protect_urls(text: str) -> tuple[str, list[str]]:
    urls: list[str] = []

    def _stash(match: re.Match[str]) -> str:
        urls.append(match.group(0))
        return f"⟦URL{len(urls) - 1}⟧"

    return _URL_TOKEN_RE.sub(_stash, text), urls


def _restore_urls(text: str, urls: list[str]) -> str:
    out = text
    for i, url in enumerate(urls):
        out = out.replace(f"⟦URL{i}⟧", url)
        out = out.replace(f"[URL{i}]", url)
    return out


def app_locale_for_iso(iso: str) -> str:
    """ISO 639-1 → app_language locale (uz_UZ / ru_RU / us_US)."""
    code = _normalize_lang(iso)
    return {
        "uz": "uz_UZ",
        "ru": "ru_RU",
        "en": "us_US",
    }.get(code, f"{code}_{code.upper()}")


def _lang_name(code: str | None) -> str:
    if not code:
        return "auto-detected"
    n = _normalize_lang(code)
    return _LANG_NAMES.get(n, n)


def _deepl_lang(code: str) -> str:
    return _normalize_lang(code).upper()


def _translation_model(settings) -> str:
    dedicated = (getattr(settings, "openai_translation_model", None) or "").strip()
    if dedicated:
        return dedicated
    return (settings.openai_model or "gpt-4o-mini").strip()


def _strip_model_wrappers(text: str) -> str:
    out = (text or "").strip()
    if not out:
        return out
    # Remove accidental labels / code fences.
    out = re.sub(r"^```(?:\w+)?\s*", "", out)
    out = re.sub(r"\s*```$", "", out)
    out = out.strip()
    # Strip wrapping quotes only when the whole string is quoted once.
    if len(out) >= 2 and out[0] == out[-1] and out[0] in {'"', "'", "“", "”", "«", "»"}:
        out = out[1:-1].strip()
    for prefix in (
        "Translation:",
        "Translated:",
        "Corrected:",
        "Output:",
        "Tarjima:",
        "Перевод:",
    ):
        if out.lower().startswith(prefix.lower()):
            out = out[len(prefix) :].strip()
    return out.strip()


async def _openai_chat(
    *,
    api_key: str,
    model: str,
    system: str,
    user: str,
    temperature: float = 0.0,
    timeout: float = 35.0,
) -> str:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "temperature": temperature,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(OPENAI_CHAT_URL, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
        ).strip()
        if not content:
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return _strip_model_wrappers(content)


def _translate_system(tgt: str, domain: str = "general") -> str:
    quality = _LANG_QUALITY.get(tgt, "Use perfect native grammar, spelling, and syntax.")
    dom = normalize_translation_domain(domain)
    domain_block = _DOMAIN_HINTS.get(dom, _DOMAIN_HINTS["general"])
    return (
        "You are AnyLang Smart Translation — a senior domain-aware professional translator "
        "for a multilingual messaging app.\n"
        "Recipients must read every chat message in their native language with "
        "ZERO spelling, grammar, or syntax mistakes — native-speaker quality only.\n\n"
        f"{domain_block}\n\n"
        "Hard rules:\n"
        "1) Output ONLY the translated message text. No quotes, labels, markdown, notes.\n"
        "2) Meaning must stay exact: do not invent, expand, summarize, or omit.\n"
        "3) Preserve names, @mentions, #hashtags, URLs, emails, phones, codes exactly.\n"
        "4) Keep emojis and relative positions; do not add/remove emojis.\n"
        "5) Match chat tone (casual/formal) and preserve line breaks.\n"
        "6) If already in the target language, or only names/emojis/symbols/numbers — return unchanged.\n"
        "7) Never produce broken word order, missing words, or misspellings.\n"
        "8) Prefer natural idiomatic phrasing over word-for-word calques.\n"
        "9) Domain terminology must be industry-correct (not casual synonyms).\n\n"
        f"Target-language quality bar:\n{quality}"
    )


def _proofread_system(tgt: str, domain: str = "general") -> str:
    quality = _LANG_QUALITY.get(tgt, "Fix every grammar, spelling, and syntax error.")
    dom = normalize_translation_domain(domain)
    domain_block = _DOMAIN_HINTS.get(dom, _DOMAIN_HINTS["general"])
    return (
        "You are a native-speaker copy editor for Smart Translation in AnyLang. "
        "Your ONLY job is to eliminate spelling, grammar, syntax, and punctuation errors "
        "while keeping the meaning identical and domain terminology correct.\n\n"
        f"{domain_block}\n\n"
        "Hard rules:\n"
        "1) Output ONLY the corrected text — no quotes, labels, or commentary.\n"
        "2) Fix: spelling, diacritics, grammar, agreement, word order, punctuation.\n"
        "3) Do NOT change meaning, add content, remove content, or rephrase style unless "
        "needed to fix an error or incorrect domain term.\n"
        "4) Preserve names, @mentions, #hashtags, URLs, emails, phones, codes, emojis exactly.\n"
        "5) Preserve line breaks.\n"
        "6) If the text is already perfect, return it unchanged.\n\n"
        f"Language focus:\n{quality}"
    )


async def _translate_openai(
    text: str,
    target: str,
    source: str | None,
    *,
    domain: str = "general",
) -> str:
    settings = get_settings()
    src_name = _lang_name(source)
    tgt_name = _lang_name(target)
    model = _translation_model(settings)
    tgt = _normalize_lang(target)
    dom = normalize_translation_domain(domain)

    draft = await _openai_chat(
        api_key=settings.openai_api_key,
        model=model,
        system=_translate_system(tgt, dom),
        user=(
            f"Source language: {src_name}\n"
            f"Target language: {tgt_name}\n"
            f"Industry domain: {dom}\n\n"
            f"Text to translate:\n{text}"
        ),
        temperature=0.0,
        timeout=35.0,
    )

    # Short / emoji-only: skip second pass.
    meaningful = re.sub(r"[\W_]+", "", draft, flags=re.UNICODE)
    if len(meaningful) < 3:
        return draft

    try:
        polished = await _openai_chat(
            api_key=settings.openai_api_key,
            model=model,
            system=_proofread_system(tgt, dom),
            user=(
                f"Language: {tgt_name}\n"
                f"Industry domain: {dom}\n"
                f"Original source ({src_name}):\n{text}\n\n"
                f"Draft translation to proofread:\n{draft}"
            ),
            temperature=0.0,
            timeout=35.0,
        )
        if (polished or "").strip():
            return polished
    except Exception as exc:  # noqa: BLE001
        logger.warning("Translation proofread skipped (%s); using draft", exc)

    return draft


async def _translate_deepl(text: str, target: str, source: str | None) -> str:
    settings = get_settings()
    api_url = DEEPL_FREE_URL if settings.deepl_api_key.endswith(":fx") else DEEPL_PRO_URL
    payload: dict[str, str | list[str]] = {
        "auth_key": settings.deepl_api_key,
        "text": [text],
        "target_lang": _deepl_lang(target),
    }
    if source:
        payload["source_lang"] = _deepl_lang(source)

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.post(api_url, data=payload)
        response.raise_for_status()
        data = response.json()
        translations = data.get("translations") or []
        if translations:
            out = str(translations[0].get("text") or "").strip()
            if out:
                return out
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
    raise AppError(
        message="Tarjima javobi bo'sh",
        error_code="TRANSLATION_FAILED",
        status_code=502,
    )


async def translate(
    text: str,
    target_lang: str,
    source_lang: str | None = None,
    *,
    domain: str | None = None,
) -> str:
    """Translate text via OpenAI (domain-aware), DeepL, or mock."""
    settings = get_settings()
    target = _normalize_lang(target_lang)
    source = _normalize_lang(source_lang) if source_lang else None
    resolved_domain = resolve_translation_domain(text, preferred=domain)

    if not text.strip():
        return text
    if source and source == target:
        return text
    # Faqat URL / invite link — tarjima qilinmasin
    if _is_url_only_message(text):
        return text

    protected, urls = _protect_urls(text)
    out = await _translate_provider(
        protected, target, source, settings, domain=resolved_domain
    )
    return _restore_urls(out, urls)


async def _translate_provider(
    text: str,
    target: str,
    source: str | None,
    settings,
    *,
    domain: str = "general",
) -> str:
    provider = (settings.translation_provider or "mock").strip().lower()

    if provider == "openai":
        if not settings.openai_api_key:
            raise AppError(
                message="OpenAI tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            out = await _translate_openai(text, target, source, domain=domain)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            logger.warning("OpenAI translation failed (%s)", exc)
            raise AppError(
                message="Tarjima xizmati vaqtincha ishlamayapti",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            ) from exc
        if not (out or "").strip():
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return out.strip()

    if provider == "deepl":
        if not settings.deepl_api_key:
            raise AppError(
                message="DeepL tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            out = await _translate_deepl(text, target, source)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            logger.warning("DeepL translation failed (%s)", exc)
            if settings.is_production:
                raise AppError(
                    message="Tarjima xizmati vaqtincha ishlamayapti",
                    error_code="TRANSLATION_FAILED",
                    status_code=502,
                ) from exc
            return f"[{target}] {text}"
        if not (out or "").strip():
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return out.strip()

    # mock
    if settings.is_production and not settings.allow_mock_translation:
        raise AppError(
            message="Tarjima xizmati sozlanmagan",
            error_code="TRANSLATION_UNAVAILABLE",
            status_code=503,
        )
    tag = normalize_translation_domain(domain)
    return f"[{target}/{tag}] {text}"


async def suggest_chat_reply(
    *,
    peer_message: str,
    reply_language: str,
    recent_context: list[str] | None = None,
    tone: str = "professional",
) -> str:
    """AI draft reply for chat — recipient language = user's preferred lang."""
    settings = get_settings()
    lang = _normalize_lang(reply_language) or "uz"
    peer = (peer_message or "").strip()
    if not peer:
        raise AppError(
            message="Javob yozish uchun xabar kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    context_block = ""
    if recent_context:
        lines = [ln.strip() for ln in recent_context if ln and ln.strip()]
        if lines:
            context_block = "Recent chat context:\n" + "\n".join(f"- {ln}" for ln in lines[-8:])

    tone_key = (tone or "professional").strip().lower()
    allowed = {
        "professional",
        "friendly",
        "sales",
        "negotiation",
        "short",
    }
    if tone_key not in allowed:
        tone_key = "professional"
    tone_hint = {
        "professional": "polite formal B2B / trade tone",
        "friendly": "warm and friendly, still clear for business partners",
        "sales": (
            "sales style: highlight value and next step with a soft CTA; "
            "do not invent discounts, prices, or guarantees"
        ),
        "negotiation": (
            "negotiation style: clarify terms, propose win-win options, "
            "ask precise questions; no hard pressure or invented commitments"
        ),
        "short": "very short and direct (1-2 sentences)",
    }.get(tone_key, "polite formal B2B / trade tone")

    system = (
        "You write chat reply drafts for AnyLang, a cross-border business messaging app.\n"
        "Hard rules:\n"
        "1) Output ONLY the reply text. No quotes, labels, markdown, or notes.\n"
        "2) Write in the user's language exactly as requested.\n"
        "3) Keep it natural for chat (not an email essay).\n"
        "4) Do not invent prices, contracts, or commitments unless present in the peer message.\n"
        "5) Prefer clear trade/business phrasing suitable for manufacturers and partners.\n"
    )
    user_prompt = (
        f"Reply language (ISO): {lang}\n"
        f"Tone: {tone_hint}\n"
        f"Peer message to answer:\n{peer}\n"
    )
    if context_block:
        user_prompt += f"\n{context_block}\n"

    if settings.openai_api_key:
        try:
            return await _openai_chat(
                api_key=settings.openai_api_key,
                model=(settings.openai_model or "gpt-4o-mini").strip(),
                system=system,
                user=user_prompt,
                temperature=0.5,
                timeout=40.0,
            )
        except AppError:
            raise
        except Exception as exc:
            logger.warning("suggest_chat_reply OpenAI failed: %s", exc)
            if settings.is_production:
                raise AppError(
                    message="AI javob hozircha mavjud emas",
                    error_code="AI_UNAVAILABLE",
                    status_code=503,
                ) from exc

    # Dev / mock fallback
    if lang.startswith("ru"):
        return f"Спасибо за сообщение. Уточните, пожалуйста: {peer[:120]}"
    if lang.startswith("en"):
        return f"Thanks for your message. Could you clarify: {peer[:120]}"
    return f"Xabaringiz uchun rahmat. Iltimos, aniqlashtiring: {peer[:120]}"


async def summarize_chat_thread(
    *,
    lines: list[str],
    summary_language: str,
    message_count: int,
) -> dict:
    """AI short deal/chat summary as title + bullet points."""
    settings = get_settings()
    lang = _normalize_lang(summary_language) or "uz"
    cleaned = [ln.strip() for ln in lines if ln and ln.strip()]
    if not cleaned:
        raise AppError(
            message="Xulosa uchun xabarlar yetarli emas",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    # Cap prompt size — newest lines already preferred by caller
    block = "\n".join(cleaned[-100:])
    system = (
        "You summarize AnyLang B2B chat threads for busy traders.\n"
        "Hard rules:\n"
        "1) Output ONLY valid JSON: "
        '{"title":"...","bullets":["...","..."]}\n'
        "2) title must be a short heading in the requested language "
        '(e.g. Uzbek "Qisqacha", Russian "Кратко", English "Summary").\n'
        "3) bullets: 3–8 short factual lines (no numbering, no markdown).\n"
        "4) Prefer deal facts: quantity, price/agreed terms, Incoterms (FOB/CIF…), "
        "delivery/ship date, MOQ, payment, open questions.\n"
        "5) Do NOT invent facts that are not in the transcript.\n"
        "6) Write bullets in the requested language.\n"
        "7) Skip greetings and small talk.\n"
    )
    user_prompt = (
        f"Summary language (ISO): {lang}\n"
        f"Total messages in chat (approx): {message_count}\n"
        f"Transcript (oldest → newest, sampled):\n{block}\n"
    )

    if settings.openai_api_key:
        try:
            raw = await _openai_chat(
                api_key=settings.openai_api_key,
                model=(settings.openai_model or "gpt-4o-mini").strip(),
                system=system,
                user=user_prompt,
                temperature=0.2,
                timeout=55.0,
            )
            parsed = _parse_summary_json(raw, lang=lang)
            if parsed["bullets"]:
                return parsed
        except AppError:
            raise
        except Exception as exc:
            logger.warning("summarize_chat_thread OpenAI failed: %s", exc)
            if settings.is_production:
                raise AppError(
                    message="AI xulosa hozircha mavjud emas",
                    error_code="AI_UNAVAILABLE",
                    status_code=503,
                ) from exc

    return _mock_chat_summary(cleaned, lang=lang)


def _parse_summary_json(raw: str, *, lang: str) -> dict:
    text = (raw or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    title_default = {
        "ru": "Кратко",
        "en": "Summary",
    }.get(lang[:2], "Qisqacha")
    try:
        data = json.loads(text)
    except Exception:
        bullets = [
            ln.lstrip("•-*–— ").strip()
            for ln in text.splitlines()
            if ln.strip() and not ln.strip().lower().startswith(("qisqacha", "кратко", "summary"))
        ]
        return {"title": title_default, "bullets": bullets[:8]}
    if not isinstance(data, dict):
        return {"title": title_default, "bullets": []}
    title = str(data.get("title") or title_default).strip() or title_default
    raw_bullets = data.get("bullets") or data.get("points") or []
    bullets: list[str] = []
    if isinstance(raw_bullets, list):
        for b in raw_bullets:
            s = str(b).strip()
            if s:
                bullets.append(s[:240])
    return {"title": title[:80], "bullets": bullets[:8]}


def _mock_chat_summary(lines: list[str], *, lang: str) -> dict:
    title = {
        "ru": "Кратко",
        "en": "Summary",
    }.get(lang[:2], "Qisqacha")
    bullets: list[str] = []
    for ln in reversed(lines):
        # Prefer offer / deal-looking lines
        low = ln.lower()
        if any(
            k in low
            for k in (
                "offer",
                "fob",
                "cif",
                "moq",
                "usd",
                "eur",
                "narx",
                "цена",
                "price",
                "dona",
                "шт",
                "pcs",
                "delivery",
                "yetkaz",
                "avgust",
                "august",
            )
        ):
            # strip "me:" / "peer:" prefixes
            body = ln.split(":", 1)[-1].strip() if ":" in ln[:8] else ln
            if body and body not in bullets:
                bullets.append(body[:180])
        if len(bullets) >= 5:
            break
    if not bullets:
        for ln in reversed(lines[-5:]):
            body = ln.split(":", 1)[-1].strip() if ":" in ln[:12] else ln
            if body:
                bullets.append(body[:160])
            if len(bullets) >= 4:
                break
    if lang.startswith("en") and not bullets:
        bullets = ["Key points will appear when the chat has more deal details."]
    elif lang.startswith("ru") and not bullets:
        bullets = ["Ключевые пункты появятся, когда в чате будет больше деталей сделки."]
    elif not bullets:
        bullets = ["Bitim tafsilotlari ko‘proq bo‘lganda xulosa aniqroq bo‘ladi."]
    return {"title": title, "bullets": bullets[:8]}
