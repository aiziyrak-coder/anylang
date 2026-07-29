# -*- coding: utf-8 -*-
"""Full UI i18n quality pass: masters + fill all locales (missing + leftover EN)."""
from __future__ import annotations

import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(r"E:\Anylang")
sys.path.insert(0, str(ROOT / "scripts"))

from generate_ui_i18n import (  # noqa: E402
    BATCH,
    OUT,
    WORKERS,
    fetch_openai_key,
    load_json,
    save_json,
    translate_batch,
    write_index,
)
from ui_locale_catalog import OPENAI_LANG_NAME, UI_LOCALES  # noqa: E402

# Intentional empties (word-order glue around clickable terms).
ALLOW_EMPTY = {"terms_agree_before", "terms_agree_after"}

# Known shared tokens that may stay English.
ALLOW_SAME_AS_EN = {
    "business_incoterms",
    "lang_name_en",
    "AnyLang",
}

MASTER_PATCH = {
    "us_US": {
        "accounts_add_subtitle": "Sign in with another email or Google — your current account stays saved.",
        "chat_attach_round_video": "Video note",
        "chat_attach_video": "Video",
        "chat_overflow_shared_media": "Media, files and links",
        "chat_preview_round_video": "⭕ Video note",
        "chat_round_video_hint": "Round video up to 1 min",
        "chat_round_video_pick_title": "Video note",
        "chat_round_video_too_long": "Video note must be under 1 min",
        "chat_search_count": "@current / @total",
        "chat_video_hint": "Up to @n seconds",
        "chat_video_pick_camera": "Camera",
        "chat_video_pick_gallery": "Gallery",
        "chat_video_pick_title": "Send video",
        "chat_video_too_long": "Video is too long",
        "chat_voice_play": "Voice message",
        "common_user": "User",
        "device_fallback_mobile": "Mobile",
        "outbox_file_missing": "Local file missing; message kept pending",
        "profile_bio": "Bio",
        "profile_bio_add": "Add a bio",
        "profile_bio_business_required_body": "Only business accounts can write a bio. Upgrade to a business plan on the plans screen.",
        "profile_bio_business_required_title": "Business account required",
        "profile_bio_edit_title": "Edit bio",
        "profile_bio_hint": "A short line about you (max 300 characters)",
        "profile_bio_placeholder": "e.g. Textile export · Tashkent",
        "profile_bio_saved": "Bio saved",
        "profile_viewers_failed": "Could not load profile viewers. Tap to retry",
        "saved_messages_hint": "Notes to yourself",
        "saved_messages_title": "Saved Messages",
        "settings_language_sync_failed": "Could not sync language to server",
        "shared_media_audio": "audio files",
        "shared_media_audio_title": "Audio",
        "shared_media_chats_count": "@n messages",
        "shared_media_empty": "Nothing here yet",
        "shared_media_files": "files",
        "shared_media_files_title": "Files",
        "shared_media_links": "shared links",
        "shared_media_links_title": "Links",
        "shared_media_photos": "photos",
        "shared_media_photos_title": "Photos",
        "shared_media_title": "Shared Media",
        "shared_media_videos": "videos",
        "shared_media_videos_title": "Videos",
        "shared_media_voice": "voice messages",
        "shared_media_voice_title": "Voice messages",
        "subscription_promo_discount": "Promo discount",
        "payment_total": "Total",
    },
    "uz_UZ": {
        "accounts_add_subtitle": "Boshqa email yoki Google bilan kiring — joriy hisobingiz saqlanib qoladi.",
        "chat_attach_round_video": "Video xabar",
        "chat_attach_video": "Video",
        "chat_overflow_shared_media": "Media, fayllar va havolalar",
        "chat_preview_round_video": "⭕ Video xabar",
        "chat_round_video_hint": "Dumaloq video — 1 daqiqagacha",
        "chat_round_video_pick_title": "Video xabar",
        "chat_round_video_too_long": "Video xabar 1 daqiqadan oshmasin",
        "chat_search_count": "@current / @total",
        "chat_video_hint": "@n soniyagacha",
        "chat_video_pick_camera": "Kamera",
        "chat_video_pick_gallery": "Galereya",
        "chat_video_pick_title": "Video yuborish",
        "chat_video_too_long": "Video juda uzun",
        "chat_voice_play": "Ovozli xabar",
        "common_user": "Foydalanuvchi",
        "device_fallback_mobile": "Mobil",
        "outbox_file_missing": "Mahalliy fayl topilmadi; xabar kutishda qoldi",
        "profile_bio": "Bio",
        "profile_bio_add": "Bio qo‘shish",
        "profile_bio_business_required_body": "Bio yozish faqat biznes hisoblar uchun. Tariflar ekranida biznes rejasiga o‘ting.",
        "profile_bio_business_required_title": "Biznes hisob kerak",
        "profile_bio_edit_title": "Bioni tahrirlash",
        "profile_bio_hint": "O‘zingiz haqingizda qisqa matn (max 300 belgi)",
        "profile_bio_placeholder": "masalan: To‘qimachilik eksporti · Toshkent",
        "profile_bio_saved": "Bio saqlandi",
        "profile_viewers_failed": "Profil ko‘rganlar yuklanmadi. Qayta urinish uchun bosing",
        "saved_messages_hint": "O‘zingiz uchun eslatmalar",
        "saved_messages_title": "Saqlangan xabarlar",
        "settings_language_sync_failed": "Tilni serverga sinxronlab bo‘lmadi",
        "shared_media_audio": "audio fayllar",
        "shared_media_audio_title": "Audio",
        "shared_media_chats_count": "@n ta xabar",
        "shared_media_empty": "Hali hech narsa yo‘q",
        "shared_media_files": "fayllar",
        "shared_media_files_title": "Fayllar",
        "shared_media_links": "ulashilgan havolalar",
        "shared_media_links_title": "Havolalar",
        "shared_media_photos": "rasmlar",
        "shared_media_photos_title": "Rasmlar",
        "shared_media_title": "Umumiy media",
        "shared_media_videos": "videolar",
        "shared_media_videos_title": "Videolar",
        "shared_media_voice": "ovozli xabarlar",
        "shared_media_voice_title": "Ovozli xabarlar",
        "subscription_promo_discount": "Promo chegirma",
        "payment_total": "Jami",
        "subscription_pay_confirm_body": "@plan\nSumma: @base\nSoliq (@percent%): @tax\nJami: @total",
        "subscription_pay_confirm_body_simple": "@plan\nJami: @total",
        "subscription_tax_breakdown": "@months oy: @base + soliq @percent% (@tax) · Jami @total",
        "subscription_tax_notice": "To‘lovga @percent% to‘lov solig‘i qo‘shiladi. Pastdagi «Jami» yakuniy summani ko‘rsatadi.",
    },
    "ru_RU": {
        "accounts_add_subtitle": "Войдите с другим email или Google — текущий аккаунт сохранится.",
        "chat_attach_round_video": "Видеосообщение",
        "chat_attach_video": "Видео",
        "chat_overflow_shared_media": "Медиа, файлы и ссылки",
        "chat_preview_round_video": "⭕ Видеосообщение",
        "chat_round_video_hint": "Круглое видео до 1 мин",
        "chat_round_video_pick_title": "Видеосообщение",
        "chat_round_video_too_long": "Видеосообщение должно быть короче 1 мин",
        "chat_search_count": "@current / @total",
        "chat_video_hint": "До @n секунд",
        "chat_video_pick_camera": "Камера",
        "chat_video_pick_gallery": "Галерея",
        "chat_video_pick_title": "Отправить видео",
        "chat_video_too_long": "Видео слишком длинное",
        "chat_voice_play": "Голосовое сообщение",
        "common_user": "Пользователь",
        "device_fallback_mobile": "Мобильный",
        "outbox_file_missing": "Локальный файл отсутствует; сообщение оставлено в ожидании",
        "profile_bio": "О себе",
        "profile_bio_add": "Добавить описание",
        "profile_bio_business_required_body": "Био могут писать только бизнес-аккаунты. Оформите бизнес-план на экране тарифов.",
        "profile_bio_business_required_title": "Нужен бизнес-аккаунт",
        "profile_bio_edit_title": "Редактировать описание",
        "profile_bio_hint": "Короткая строка о вас (макс. 300 символов)",
        "profile_bio_placeholder": "напр. Экспорт текстиля · Ташкент",
        "profile_bio_saved": "Описание сохранено",
        "profile_viewers_failed": "Не удалось загрузить просмотры профиля. Нажмите, чтобы повторить",
        "saved_messages_hint": "Заметки для себя",
        "saved_messages_title": "Избранное",
        "settings_language_sync_failed": "Не удалось синхронизировать язык с сервером",
        "shared_media_audio": "аудиофайлы",
        "shared_media_audio_title": "Аудио",
        "shared_media_chats_count": "@n сообщений",
        "shared_media_empty": "Пока пусто",
        "shared_media_files": "файлы",
        "shared_media_files_title": "Файлы",
        "shared_media_links": "общие ссылки",
        "shared_media_links_title": "Ссылки",
        "shared_media_photos": "фото",
        "shared_media_photos_title": "Фото",
        "shared_media_title": "Общие медиа",
        "shared_media_videos": "видео",
        "shared_media_videos_title": "Видео",
        "shared_media_voice": "голосовые сообщения",
        "shared_media_voice_title": "Голосовые",
        "subscription_promo_discount": "Промо-скидка",
        "payment_total": "Итого",
    },
}

PH = re.compile(r"@\w+|%\w+|\{[^}]+\}")


def placeholders(s: str) -> set[str]:
    return set(PH.findall(s or ""))


def patch_masters() -> dict[str, str]:
    for code, patch in MASTER_PATCH.items():
        data = load_json(code)
        data.update(patch)
        save_json(code, data)
        print("patched master", code, "keys", len(data))
    return load_json("us_US")


def needs_retranslate(key: str, en_val: str, cur: str | None) -> bool:
    if cur is None:
        return True
    if key in ALLOW_EMPTY:
        return False
    if not str(cur).strip() and key not in ALLOW_EMPTY:
        return True
    if key in ALLOW_SAME_AS_EN:
        return False
    if key.startswith("lang_name_"):
        return False
    # leftover English UI copy
    if cur == en_val and len(en_val) >= 12:
        # keep pure brand / short codes
        if en_val.strip() in {"AnyLang", "OK", "USD", "EUR", "FOB", "CIF", "MOQ", "OEM", "ODM"}:
            return False
        return True
    return False


def validate_locale(code: str, en: dict[str, str], data: dict[str, str]) -> list[str]:
    issues: list[str] = []
    for k, ev in en.items():
        if k not in data:
            issues.append(f"missing:{k}")
            continue
        v = data[k]
        if k not in ALLOW_EMPTY and isinstance(v, str) and not v.strip():
            issues.append(f"empty:{k}")
        if placeholders(ev) != placeholders(str(v)):
            issues.append(f"placeholder:{k}")
    return issues


def fill_locale(api_key: str, code: str, en: dict[str, str], translate_fn) -> None:
    target_name = OPENAI_LANG_NAME[code]
    data = load_json(code) if (OUT / f"{code}.json").exists() else {}
    todo = {
        k: en[k]
        for k in en
        if needs_retranslate(k, en[k], data.get(k))
    }
    print(f"{code}: todo={len(todo)} / {len(en)}", flush=True)
    if not todo:
        # still ensure all keys present
        for k, v in en.items():
            data.setdefault(k, v)
        save_json(code, data)
        return

    keys = list(todo)
    for i in range(0, len(keys), BATCH):
        chunk = {k: todo[k] for k in keys[i : i + BATCH]}
        translated = translate_fn(api_key, target_name, chunk)
        # placeholder repair: if broken, keep English and retry once later
        for k, tv in translated.items():
            if placeholders(en[k]) != placeholders(tv):
                print(f"  warn placeholder {code}.{k} — fallback EN")
                translated[k] = en[k]
        data.update(translated)
        print(f"  {code} {min(i + BATCH, len(keys))}/{len(keys)}", flush=True)
        save_json(code, data)

    for k, v in en.items():
        data.setdefault(k, v)
    # preserve intentional empties from EN
    for k in ALLOW_EMPTY:
        if k in en:
            data[k] = en[k]
    save_json(code, data)


def main() -> int:
    en = patch_masters()
    write_index()
    api_key = fetch_openai_key()
    os.environ["OPENAI_API_KEY"] = api_key
    print("OpenAI key: OK")

    # Stronger quality system prompt for this pass
    import httpx

    def translate_batch_hq(api_key: str, target_name: str, batch: dict[str, str]) -> dict[str, str]:
        system = (
            "You are a professional native localization editor for the AnyLang mobile app. "
            "Translate UI strings into the target language with PERFECT grammar, spelling, "
            "and natural app tone. Return ONLY a JSON object with the SAME keys. "
            "Rules: (1) Preserve placeholders EXACTLY: @n @count @name @amount @percent "
            "@base @tax @total @plan @months @days @current @time @pos @date {name} %s. "
            "(2) Keep brand AnyLang unchanged. (3) Keep emojis unchanged. "
            "(4) No transliteration garbage; no leftover English unless the source is a "
            "brand/acronym (API, USD, FOB). (5) Do not add/remove keys. No markdown."
        )
        user = {"target_language": target_name, "strings": batch}

        with httpx.Client(timeout=180.0) as client:
            for attempt in range(6):
                try:
                    r = client.post(
                        "https://api.openai.com/v1/chat/completions",
                        headers={"Authorization": f"Bearer {api_key}"},
                        json={
                            "model": "gpt-4o-mini",
                            "temperature": 0.05,
                            "response_format": {"type": "json_object"},
                            "messages": [
                                {"role": "system", "content": system},
                                {
                                    "role": "user",
                                    "content": json.dumps(user, ensure_ascii=False),
                                },
                            ],
                        },
                    )
                    if r.status_code == 429:
                        time.sleep(6 + attempt * 4)
                        continue
                    r.raise_for_status()
                    content = r.json()["choices"][0]["message"]["content"]
                    parsed = json.loads(content)
                    if "strings" in parsed and isinstance(parsed["strings"], dict):
                        parsed = parsed["strings"]
                    out: dict[str, str] = {}
                    for k, v in batch.items():
                        tv = parsed.get(k)
                        out[k] = tv.strip() if isinstance(tv, str) and tv.strip() else v
                    return out
                except Exception as e:
                    print(f"    retry {attempt+1}: {type(e).__name__}: {e}")
                    time.sleep(2 + attempt * 2)
        return dict(batch)

    targets = [
        code
        for _, code, *_ in UI_LOCALES
        if code not in ("uz_UZ", "ru_RU", "us_US")
    ]
    only = os.environ.get("I18N_ONLY", "").strip()
    if only:
        targets = [t for t in targets if t == only or t.startswith(only)]

    # Process locales (sequential per locale, batches inside)
    for code in targets:
        fill_locale(api_key, code, en, translate_batch_hq)

    # Final audit
    print("\n=== AUDIT ===")
    bad = 0
    for _, code, *_ in UI_LOCALES:
        data = load_json(code)
        issues = validate_locale(code, en, data)
        # for non-en count leftover English (long)
        leftover = 0
        if code != "us_US":
            leftover = sum(
                1
                for k, v in en.items()
                if needs_retranslate(k, v, data.get(k)) and data.get(k) == v
            )
        print(
            f"{code}: keys={len(data)} issues={len(issues)} leftover_en={leftover}"
        )
        if issues:
            bad += 1
            print(" ", issues[:8])
    write_index()
    print("done, locales_with_issues", bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
