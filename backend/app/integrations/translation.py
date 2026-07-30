import logging
import json
import hashlib
import re
from collections import OrderedDict

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

# Reused HTTP client (TLS/keepalive) — major latency win under load.
_openai_http: httpx.AsyncClient | None = None

# Identical short chat lines often repeat — skip re-paying tokens.
_TRANSLATE_CACHE: OrderedDict[str, str] = OrderedDict()
_TRANSLATE_CACHE_MAX = 2048

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
        "Uzbek Latin (o‘/g‘, not o'/g'). Sound like a native speaker in chat. "
        "NEVER calque English/Russian word order. "
        "Pronouns must keep the SAME subject/object as the source "
        "(e.g. 'I liked your app' → 'Ilovangiz menga juda yoqdi', "
        "NOT 'sizga … yoqdi'). "
        "Use natural idioms: impressed → 'hayratda qoldim' / 'ta’sir qildi', "
        "NOT literal nonsense like 'ichimga sindi'."
    ),
    "ru": (
        "Natural Russian chat: cases, gender, aspect perfect. "
        "No English calques; keep who did what to whom exact."
    ),
    "en": (
        "Natural English chat: articles, tense, prepositions perfect. "
        "Idiomatic; keep subject/object roles exact."
    ),
    "tr": "Turkish: vowel harmony + agglutination; natural chat; exact roles.",
    "ar": "Natural Arabic chat; correct grammar; exact meaning & pronouns.",
    "zh": "Natural Simplified Chinese; idiomatic; exact who/whom.",
    "ja": "Natural Japanese; correct particles/politeness; exact roles.",
    "ko": "Natural Korean; correct honorifics when implied; exact roles.",
    "de": "Natural German chat; cases/articles correct; exact roles.",
    "fr": "Natural French chat; gender/agreement correct; exact roles.",
    "es": "Natural Spanish chat; gender/agreement correct; exact roles.",
    "pt": "Natural Portuguese; consistent variant; exact roles.",
    "uk": "Natural Ukrainian; correct cases; exact roles.",
    "kk": "Natural Kazakh orthography & grammar; exact roles.",
    "hi": "Natural Hindi (Devanagari); exact roles; no calques.",
    "ku": "Natural Kurmanji Kurdish; idiomatic; exact subject/object.",
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
    "medical": "MEDICAL: precise clinical terms; never invent drugs/dosages.",
    "legal": "LEGAL: preserve legal force; keep defined terms consistent.",
    "textile": "TEXTILE: GSM/MOQ/OEM/fabric specs exact.",
    "it": "IT: keep API/SDK/code/paths/commands untranslated.",
    "construction": "CONSTRUCTION: keep grades/units/standards exact.",
    "general": "",
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
    return (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"


def _cache_key(
    text: str,
    target: str,
    source: str | None,
    domain: str,
    model: str,
) -> str:
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()
    return f"{model}|{source or '-'}|{target}|{domain}|{digest}"


def _cache_get(key: str) -> str | None:
    hit = _TRANSLATE_CACHE.get(key)
    if hit is None:
        return None
    _TRANSLATE_CACHE.move_to_end(key)
    return hit


def _cache_put(key: str, value: str) -> None:
    _TRANSLATE_CACHE[key] = value
    _TRANSLATE_CACHE.move_to_end(key)
    while len(_TRANSLATE_CACHE) > _TRANSLATE_CACHE_MAX:
        _TRANSLATE_CACHE.popitem(last=False)


def _max_output_tokens(text: str) -> int:
    """Enough room for idiomatic expansion; still capped for cost."""
    # Some languages expand a lot vs English; don't truncate mid-thought.
    est = max(96, (len(text) // 2) + 64)
    return min(est, 900)


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


async def _openai_http_client(timeout: float) -> httpx.AsyncClient:
    global _openai_http
    if _openai_http is None or _openai_http.is_closed:
        _openai_http = httpx.AsyncClient(
            timeout=httpx.Timeout(timeout, connect=4.0),
            limits=httpx.Limits(max_keepalive_connections=32, max_connections=64),
        )
    return _openai_http


async def _openai_chat(
    *,
    api_key: str,
    model: str,
    system: str,
    user: str,
    temperature: float = 0.0,
    timeout: float = 18.0,
    max_tokens: int | None = None,
) -> str:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload: dict = {
        "model": model,
        "temperature": temperature,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    if max_tokens is not None:
        payload["max_tokens"] = max_tokens
    client = await _openai_http_client(timeout)
    try:
        response = await client.post(OPENAI_CHAT_URL, headers=headers, json=payload)
        response.raise_for_status()
    except httpx.TimeoutException:
        # One retry with a fresh client on timeout / stale connection.
        global _openai_http
        if _openai_http is not None:
            try:
                await _openai_http.aclose()
            except Exception:  # noqa: BLE001
                pass
            _openai_http = None
        client = await _openai_http_client(timeout)
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
    """Professional chat-translator brief (meaning + grammar first)."""
    quality = _LANG_QUALITY.get(
        tgt,
        "Native grammar, spelling, syntax — zero errors; idiomatic chat.",
    )
    dom = normalize_translation_domain(domain)
    domain_line = _DOMAIN_HINTS.get(dom, "")
    parts = [
        f"You are a professional human translator for messenger chat → {_lang_name(tgt)}.",
        "Think meaning first, then rewrite as a native would actually type in chat.",
        "OUTPUT RULES:",
        "1) Return ONLY the translation — no quotes, labels, notes, or markdown.",
        "2) Preserve exact meaning, tone, and politeness. Do not invent or omit facts.",
        "3) Keep subject/object/pronoun roles identical to the source (who likes whom, who asks whom).",
        "4) Prefer natural idioms over word-for-word calques. Never produce awkward literal phrases.",
        "5) Fix source grammar only if needed for a fluent target; do not change the intended sense.",
        "6) Keep names, @mentions, #hashtags, URLs, emails, phones, codes, emojis, and line breaks unchanged.",
        "7) If the text is already in the target language, or only symbols/names, return it unchanged.",
        f"TARGET QUALITY: {quality}",
    ]
    if domain_line:
        parts.append(domain_line)
    return "\n".join(parts)


async def _translate_openai(
    text: str,
    target: str,
    source: str | None,
    *,
    domain: str = "general",
    fast: bool = False,
) -> str:
    settings = get_settings()
    src = _normalize_lang(source) if source else None
    tgt = _normalize_lang(target)
    dom = normalize_translation_domain(domain)
    # One fast model for Live + chat: quality via prompt, cost via max_tokens + no 2nd pass.
    model = (
        (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
        if fast
        else _translation_model(settings)
    )

    key = _cache_key(text, tgt, src, dom, model)
    cached = _cache_get(key)
    if cached is not None:
        return cached

    src_name = _lang_name(src)
    tgt_name = _lang_name(tgt)
    user_msg = (
        f"Translate the following chat message from {src_name} into {tgt_name}.\n"
        "Write as a native speaker would in everyday chat — natural, clear, correct.\n"
        "Do not translate word-by-word if that sounds wrong.\n\n"
        f"SOURCE:\n{text}"
    )

    out = await _openai_chat(
        api_key=settings.openai_api_key,
        model=model,
        system=_translate_system(tgt, dom),
        user=user_msg,
        # Slight creativity helps idiomatic phrasing; keep low for fidelity.
        temperature=0.15 if not fast else 0.05,
        timeout=14.0 if fast else 28.0,
        max_tokens=_max_output_tokens(text),
    )
    if (out or "").strip():
        _cache_put(key, out)
    return out


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
    fast: bool = False,
) -> str:
    """Translate text via OpenAI (domain-aware), DeepL, or mock.

    fast=True — single-pass, shorter timeout (Live turns).
    """
    settings = get_settings()
    target = _normalize_lang(target_lang)
    source = _normalize_lang(source_lang) if source_lang else None
    resolved_domain = "general" if fast else resolve_translation_domain(text, preferred=domain)

    if not text.strip():
        return text
    if source and source == target:
        return text
    # Faqat URL / invite link — tarjima qilinmasin
    if _is_url_only_message(text):
        return text

    protected, urls = _protect_urls(text)
    out = await _translate_provider(
        protected,
        target,
        source,
        settings,
        domain=resolved_domain,
        fast=fast,
    )
    return _restore_urls(out, urls)


async def _translate_provider(
    text: str,
    target: str,
    source: str | None,
    settings,
    *,
    domain: str = "general",
    fast: bool = False,
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
            out = await _translate_openai(
                text, target, source, domain=domain, fast=fast
            )
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
        '{"title":"...","bullets":["...","..."],'
        '"latest_topic":"...","latest_topic_is_greeting_only":false,'
        '"previous_topic":"..." or null}\n'
        "2) title must be a short heading in the requested language "
        '(e.g. Uzbek "Qisqacha", Russian "Кратко", English "Summary").\n'
        "3) bullets: 3–8 short factual lines (no numbering, no markdown).\n"
        "4) Prefer deal facts: quantity, price/agreed terms, Incoterms (FOB/CIF…), "
        "delivery/ship date, MOQ, payment, open questions.\n"
        "5) Do NOT invent facts that are not in the transcript.\n"
        "6) Write title, bullets, and topic summaries in the requested language.\n"
        "7) Skip greetings and small talk in bullets.\n"
        "8) Split the transcript into distinct conversation TOPICS "
        "(topic change = new subject, not just a new message). "
        "From newest to oldest:\n"
        "   - latest_topic: 1–2 short sentences about what the MOST RECENT topic was about.\n"
        "   - previous_topic: 1–2 short sentences about the topic BEFORE that, "
        "or null if there is no earlier distinct topic.\n"
        "9) If the latest topic is ONLY greetings / how-are-you / small talk "
        "with no business substance, set latest_topic_is_greeting_only=true "
        "and put a brief note in latest_topic (client may replace the text).\n"
        "10) previous_topic must be null (not empty string) when absent.\n"
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
    empty_topics = {
        "latest_topic": None,
        "latest_topic_is_greeting_only": False,
        "previous_topic": None,
    }
    try:
        data = json.loads(text)
    except Exception:
        bullets = [
            ln.lstrip("•-*–— ").strip()
            for ln in text.splitlines()
            if ln.strip() and not ln.strip().lower().startswith(("qisqacha", "кратко", "summary"))
        ]
        return {"title": title_default, "bullets": bullets[:8], **empty_topics}
    if not isinstance(data, dict):
        return {"title": title_default, "bullets": [], **empty_topics}
    title = str(data.get("title") or title_default).strip() or title_default
    raw_bullets = data.get("bullets") or data.get("points") or []
    bullets: list[str] = []
    if isinstance(raw_bullets, list):
        for b in raw_bullets:
            s = str(b).strip()
            if s:
                bullets.append(s[:240])
    latest = data.get("latest_topic")
    latest_s = str(latest).strip()[:400] if latest is not None else ""
    greeting_only = bool(data.get("latest_topic_is_greeting_only"))
    prev = data.get("previous_topic")
    prev_s = None
    if prev is not None:
        p = str(prev).strip()[:400]
        if p and p.lower() not in {"null", "none", "-"}:
            prev_s = p
    return {
        "title": title[:80],
        "bullets": bullets[:8],
        "latest_topic": latest_s or None,
        "latest_topic_is_greeting_only": greeting_only,
        "previous_topic": prev_s,
    }


def _greeting_like(text: str) -> bool:
    low = (text or "").lower()
    keys = (
        "salom",
        "assalom",
        "hello",
        "hi ",
        "hey",
        "привет",
        "здравствуй",
        "qalaysiz",
        "qalesiz",
        "how are you",
        "yahshimisiz",
        "добрый",
    )
    return any(k in low for k in keys)


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

    recent = lines[-4:] if lines else []
    older = lines[-8:-4] if len(lines) > 4 else []
    latest_bodies = [
        (ln.split(":", 1)[-1].strip() if ":" in ln[:12] else ln)[:160]
        for ln in recent
        if ln.strip()
    ]
    older_bodies = [
        (ln.split(":", 1)[-1].strip() if ":" in ln[:12] else ln)[:160]
        for ln in older
        if ln.strip()
    ]
    greeting_only = bool(latest_bodies) and all(
        _greeting_like(b) for b in latest_bodies
    )
    latest = "; ".join(latest_bodies[:2]) if latest_bodies else None
    previous = "; ".join(older_bodies[:2]) if older_bodies else None

    return {
        "title": title,
        "bullets": bullets[:8],
        "latest_topic": latest,
        "latest_topic_is_greeting_only": greeting_only,
        "previous_topic": previous,
    }
