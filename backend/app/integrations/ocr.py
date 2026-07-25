"""Image OCR via OpenAI Vision — matnni rasmdan o‘qish."""

from __future__ import annotations

import base64
import json
import logging
import re

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_MAX_IMAGE_BYTES = 8 * 1024 * 1024


def _guess_mime(content_type: str | None, filename: str | None) -> str:
    mime = (content_type or "").split(";")[0].strip().lower()
    if mime in {"image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"}:
        return "image/jpeg" if mime == "image/jpg" else mime
    name = (filename or "").lower()
    if name.endswith(".png"):
        return "image/png"
    if name.endswith(".webp"):
        return "image/webp"
    if name.endswith(".gif"):
        return "image/gif"
    return "image/jpeg"


async def extract_text_from_image(
    data: bytes,
    *,
    content_type: str | None = None,
    filename: str | None = None,
    hint_lang: str | None = None,
) -> dict:
    """Return ``{ "text": str, "detected_language": str | None }``."""
    if not data:
        raise AppError(
            message="Rasm bo‘sh",
            error_code="EMPTY_IMAGE",
            status_code=400,
        )
    if len(data) > _MAX_IMAGE_BYTES:
        raise AppError(
            message="Rasm juda katta",
            error_code="FILE_TOO_LARGE",
            status_code=413,
        )

    settings = get_settings()
    api_key = (settings.openai_api_key or "").strip()
    if not api_key:
        raise AppError(
            message="OCR sozlanmagan (OpenAI)",
            error_code="OCR_UNAVAILABLE",
            status_code=503,
        )

    mime = _guess_mime(content_type, filename)
    b64 = base64.b64encode(data).decode("ascii")
    data_url = f"data:{mime};base64,{b64}"
    model = (settings.openai_model or "gpt-4o-mini").strip() or "gpt-4o-mini"
    hint = (hint_lang or "").strip().lower()[:8]
    hint_line = (
        f" Hint: text may be in language code '{hint}'." if hint else ""
    )

    system = (
        "You are an OCR engine for a travel/translator app. "
        "Extract ALL readable text from the image accurately. "
        "Reply ONLY JSON: "
        '{"text":"extracted text","detected_language":"uz|en|ru|...|null"}. '
        "Keep original line breaks when useful. "
        "If no text is visible, return {\"text\":\"\",\"detected_language\":null}."
        f"{hint_line}"
    )

    payload = {
        "model": model,
        "temperature": 0,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "Extract the text from this image.",
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": data_url, "detail": "high"},
                    },
                ],
            },
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
            if resp.status_code >= 400:
                logger.warning(
                    "OCR OpenAI HTTP %s: %s",
                    resp.status_code,
                    (resp.text or "")[:240],
                )
                raise AppError(
                    message="Matnni o‘qib bo‘lmadi",
                    error_code="OCR_FAILED",
                    status_code=502,
                )
            body = resp.json()
    except AppError:
        raise
    except Exception as exc:
        logger.warning("OCR failed: %s", exc)
        raise AppError(
            message="Matnni o‘qib bo‘lmadi",
            error_code="OCR_FAILED",
            status_code=502,
        ) from exc

    content = (
        ((body.get("choices") or [{}])[0].get("message") or {}).get("content")
        or ""
    ).strip()
    try:
        parsed = json.loads(content) if content else {}
    except json.JSONDecodeError:
        parsed = {"text": content, "detected_language": None}

    text = str(parsed.get("text") or "").strip()
    # Normalize whitespace a bit but keep paragraphs.
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)

    detected = parsed.get("detected_language")
    lang = None
    if detected:
        lang = str(detected).strip().lower().split("-")[0].split("_")[0][:8]
        if not lang or lang in {"null", "none", "unknown"}:
            lang = None

    return {"text": text, "detected_language": lang}
