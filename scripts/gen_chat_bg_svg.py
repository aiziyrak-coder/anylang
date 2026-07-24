from pathlib import Path


def icon_defs(stroke: str, sw: float = 1.35) -> dict[str, str]:
    return {
        "rocket": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 2c4 6 5 12 4 18l-4 2-4-2c-1-6 0-12 4-18z"/>
            <circle cx="14" cy="12" r="2.2"/>
            <path d="M8 16l-3 5M20 16l3 5M11 22l3 4 3-4"/>
          </g>""",
        "bulb": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 3a7 7 0 0 1 4 12.5V19H10v-3.5A7 7 0 0 1 14 3z"/>
            <path d="M11 22h6M12 19v3M16 19v3"/>
            <path d="M14 8v3"/>
          </g>""",
        "gear": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="14" cy="14" r="4"/>
            <path d="M14 3v3M14 22v3M3 14h3M22 14h3M6.2 6.2l2.1 2.1M19.8 19.8l-2.1-2.1M19.8 6.2l-2.1 2.1M6.2 19.8l2.1-2.1"/>
            <circle cx="14" cy="14" r="9" stroke-dasharray="2.5 3.2"/>
          </g>""",
        "globe": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="14" cy="14" r="10"/>
            <ellipse cx="14" cy="14" rx="4.5" ry="10"/>
            <path d="M4 14h20M6.5 8.5h15M6.5 19.5h15"/>
          </g>""",
        "envelope": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="7" width="22" height="14" rx="2"/>
            <path d="M3 9l11 7 11-7"/>
          </g>""",
        "chat": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 6h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H12l-5 4v-4H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/>
            <path d="M8 12h8M8 15h5"/>
          </g>""",
        "pencil": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 3l5 5-13 13H5v-5L18 3z"/>
            <path d="M15.5 5.5l5 5"/>
          </g>""",
        "chart": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M4 22V6M4 22h20"/>
            <path d="M8 18V12M13 18V8M18 18v-6"/>
          </g>""",
        "search": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="7"/>
            <path d="M17.5 17.5L23 23"/>
          </g>""",
        "heart": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 23s-9-5.8-9-12a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 6.2-9 12-9 12z"/>
          </g>""",
        "phone": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <rect x="8" y="2" width="12" height="24" rx="2.5"/>
            <path d="M12 20h4"/>
          </g>""",
        "laptop": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <rect x="5" y="5" width="18" height="12" rx="1.5"/>
            <path d="M2 20h24M9 17h10"/>
          </g>""",
        "headphones": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 15v-2a9 9 0 0 1 18 0v2"/>
            <path d="M5 15v5a2 2 0 0 0 2 2h2v-7H7a2 2 0 0 0-2 2zM23 15v5a2 2 0 0 1-2 2h-2v-7h2a2 2 0 0 1 2 2z"/>
          </g>""",
        "star": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 3l2.6 7.2H24l-6 4.4 2.3 7.2L14 17.6 7.7 21.8 10 14.6 4 10.2h7.4z"/>
          </g>""",
        "wave": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2 14c3-6 6-6 9 0s6 6 9 0 6-6 9 0"/>
          </g>""",
        "dots": f"""
          <g fill="{stroke}" stroke="none">
            <circle cx="6" cy="14" r="1.6"/><circle cx="14" cy="14" r="1.6"/><circle cx="22" cy="14" r="1.6"/>
          </g>""",
        "plane": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 15l21-8-8 21-3-8-8-3z"/>
          </g>""",
        "book": f"""
          <g fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 4h8a3 3 0 0 1 3 3v15a2.5 2.5 0 0 0-2.5-2.5H5z"/>
            <path d="M23 4h-8a3 3 0 0 0-3 3v15a2.5 2.5 0 0 1 2.5-2.5H23z"/>
          </g>""",
    }


PLACEMENTS = [
    ("rocket", 18, 12, 0.85, -18),
    ("bulb", 110, 8, 0.8, 12),
    ("gear", 185, 30, 0.75, 0),
    ("chat", 40, 70, 0.78, -8),
    ("globe", 145, 75, 0.72, 5),
    ("envelope", 8, 130, 0.7, 10),
    ("pencil", 95, 125, 0.75, -25),
    ("chart", 175, 140, 0.7, 0),
    ("search", 55, 185, 0.72, 15),
    ("heart", 140, 190, 0.55, -10),
    ("phone", 200, 200, 0.6, 8),
    ("laptop", 20, 240, 0.7, -5),
    ("headphones", 110, 245, 0.68, 0),
    ("star", 185, 260, 0.5, 20),
    ("wave", 70, 300, 0.7, 0),
    ("plane", 160, 310, 0.65, -30),
    ("book", 15, 340, 0.55, 0),
    ("dots", 100, 355, 0.7, 0),
    ("bulb", 200, 350, 0.55, -15),
    ("gear", 80, 40, 0.45, 20),
    ("rocket", 210, 100, 0.5, 25),
    ("chat", 120, 340, 0.5, 12),
    ("globe", 40, 300, 0.45, -10),
    ("heart", 210, 160, 0.4, 0),
    ("wave", 10, 200, 0.5, 0),
    ("star", 90, 210, 0.4, -20),
]


def make_svg(stroke: str, sw: float = 1.4) -> str:
    icons = icon_defs(stroke, sw)
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 400" width="240" height="400" fill="none">',
        "  <!-- AnyLang chat doodle wallpaper tile (vector) -->",
    ]
    for name, x, y, scale, rot in PLACEMENTS:
        body = icons[name].strip()
        parts.append(
            f'  <g transform="translate({x},{y}) rotate({rot}) scale({scale})">{body}</g>'
        )
    parts.append("</svg>")
    return "\n".join(parts)


def main() -> None:
    out = Path(r"E:\Anylang\Anylang\assets\images")
    (out / "chat_bg_light.svg").write_text(make_svg("#9B8BB8", 1.45), encoding="utf-8")
    (out / "chat_bg_dark.svg").write_text(make_svg("#6E64A8", 1.35), encoding="utf-8")
    print("ok", out / "chat_bg_light.svg")


if __name__ == "__main__":
    main()
