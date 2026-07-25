"""Jonli tarix eksporti — TXT va oddiy (Unicode) PDF."""

from __future__ import annotations

import io
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _find_font(size: int = 18) -> ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\arial.ttf"),
        Path(r"C:\Windows\Fonts\segoeui.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
        Path("/Library/Fonts/Arial Unicode.ttf"),
    ]
    for path in candidates:
        if path.is_file():
            try:
                return ImageFont.truetype(str(path), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def build_export_text(
    *,
    title: str,
    sessions: list[dict],
) -> str:
    lines: list[str] = [
        title,
        f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "=" * 48,
        "",
    ]
    for session in sessions:
        started = session.get("started_at")
        started_s = (
            started.strftime("%Y-%m-%d %H:%M")
            if isinstance(started, datetime)
            else str(started or "")
        )
        langs = f"{session.get('my_language', '?')} ↔ {session.get('other_language', '?')}"
        lines.append(f"## Session #{session.get('id')} · {started_s} · {langs}")
        lines.append("-" * 40)
        for turn in session.get("turns") or []:
            at = turn.get("created_at")
            at_s = (
                at.strftime("%H:%M")
                if isinstance(at, datetime)
                else str(at or "")[:16]
            )
            who = "Me" if turn.get("speaker") == "me" else "Partner"
            original = (turn.get("text_original") or "").strip()
            translated = (turn.get("text_translated") or "").strip()
            if not original and not translated:
                continue
            lines.append(f"[{at_s}] {who}")
            if original:
                lines.append(original)
            if translated:
                lines.append(f"→ {translated}")
            lines.append("")
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def _wrap_line(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.ImageFont,
    max_w: int,
) -> list[str]:
    words = (text or "").split(" ")
    if not words:
        return [""]
    rows: list[str] = []
    cur = words[0]
    for w in words[1:]:
        trial = f"{cur} {w}"
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            rows.append(cur)
            cur = w
    rows.append(cur)
    return rows


def build_export_pdf(*, title: str, sessions: list[dict]) -> bytes:
    text = build_export_text(title=title, sessions=sessions)
    font = _find_font(16)
    title_font = _find_font(20)
    page_w, page_h = 1240, 1754
    margin = 64
    line_h = 28
    max_w = page_w - margin * 2

    pages: list[Image.Image] = []
    img = Image.new("RGB", (page_w, page_h), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    y = margin
    draw.text((margin, y), title[:80], fill=(20, 20, 20), font=title_font)
    y += line_h + 12

    for raw_line in text.splitlines():
        wrapped = _wrap_line(draw, raw_line, font, max_w) if raw_line else [""]
        for row in wrapped:
            if y + line_h > page_h - margin:
                pages.append(img)
                img = Image.new("RGB", (page_w, page_h), (255, 255, 255))
                draw = ImageDraw.Draw(img)
                y = margin
            draw.text((margin, y), row, fill=(30, 30, 30), font=font)
            y += line_h
    pages.append(img)

    jpeg_pages: list[bytes] = []
    for page in pages:
        buf = io.BytesIO()
        page.save(buf, format="JPEG", quality=85)
        jpeg_pages.append(buf.getvalue())
    return _jpeg_images_to_pdf(jpeg_pages, page_w, page_h)


def _jpeg_images_to_pdf(jpegs: list[bytes], width: int, height: int) -> bytes:
    objects: list[bytes] = [b"", b""]  # 1 catalog, 2 pages
    page_nums: list[int] = []

    def add(obj: bytes) -> int:
        objects.append(obj)
        return len(objects)

    for jpeg in jpegs:
        img_n = add(
            b"<< /Type /XObject /Subtype /Image /Width %d /Height %d "
            b"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode "
            b"/Length %d >>\nstream\n" % (width, height, len(jpeg))
            + jpeg
            + b"\nendstream"
        )
        content = f"q\n{width} 0 0 {height} 0 0 cm\n/Im0 Do\nQ\n".encode("ascii")
        content_n = add(
            b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream"
        )
        page_n = add(
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] "
            b"/Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>"
            % (width, height, img_n, content_n)
        )
        page_nums.append(page_n)

    kids = " ".join(f"{n} 0 R" for n in page_nums).encode("ascii")
    objects[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[1] = b"<< /Type /Pages /Count %d /Kids [%s] >>" % (len(page_nums), kids)

    out = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for i, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out.extend(f"{i} 0 obj\n".encode("ascii"))
        out.extend(obj)
        out.extend(b"\nendobj\n")
    xref_pos = len(out)
    out.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode("ascii"))
    out.extend(
        (
            f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n"
        ).encode("ascii")
    )
    return bytes(out)
