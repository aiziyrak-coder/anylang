"""Generate manufacturer outreach list for AnyLang partner invitations."""

from __future__ import annotations

import csv
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs" / "outreach" / "manufacturer_outreach.csv"

rows: list[dict] = []


def add(**kw) -> None:
    rows.append(
        {
            "id": "",
            "region": kw.get("region", ""),
            "country": kw.get("country", ""),
            "category_code": kw.get("cat", ""),
            "company_name": kw.get("name", ""),
            "source_type": kw.get("src", "named_company"),
            "public_profile_url": kw.get("url", ""),
            "website": kw.get("web", ""),
            "contact_via": kw.get("via", "Alibaba message / website contact"),
            "priority": kw.get("pri", "P1"),
            "status": "todo",
            "notes": kw.get("notes", ""),
            "target_products": kw.get("products", 5),
        }
    )


# --- China: named public profiles ---
for cat, name, url, web, notes in [
    (
        "fabric_textiles",
        "Changzhou Jietai Textile Co., Ltd.",
        "https://czjiet.en.alibaba.com/",
        "",
        "Oxford/polyester fabrics",
    ),
    (
        "fabric_textiles",
        "Haining Yize Textile Co., Ltd.",
        "https://zjyize.en.alibaba.com/",
        "",
        "Verified textile; factory reports",
    ),
    (
        "fabric_textiles",
        "Changxing Yaru Textile Trade Co., Ltd.",
        "https://yarutex.en.alibaba.com/",
        "",
        "Microfiber / bedding fabric",
    ),
    (
        "fabric_textiles",
        "Changxing Ruiyuan Textile Co., Ltd.",
        "https://cxryfz.en.alibaba.com/",
        "",
        "Intertek onsite; polyester fabrics",
    ),
    (
        "energy_solar",
        "Hangzhou Shinedo Technology Co., Ltd.",
        "https://shinedo.en.alibaba.com/",
        "",
        "Solar lights / outdoor solar",
    ),
    (
        "energy_solar",
        "Guangdong Zhongyang Optoelectronic Technology Co., Ltd.",
        "",
        "https://zhongyangopto.com/en/",
        "LED + solar modules OEM",
    ),
    (
        "furniture",
        "Foshan Shunde Govan Furniture Co., Ltd.",
        "https://govanfurniture.en.alibaba.com/",
        "",
        "Foshan furniture",
    ),
    (
        "furniture",
        "Foshan Lianjiang Furniture Co., Ltd.",
        "https://lianjiang.en.alibaba.com/",
        "",
        "12yrs Alibaba furniture",
    ),
    (
        "furniture",
        "Guangdong Yabo Furniture Industries Co., Ltd.",
        "https://yabo.en.alibaba.com/",
        "",
        "Verified Pro; dining furniture",
    ),
    (
        "furniture",
        "Foshan Yisheng Furniture Co., Ltd.",
        "https://fsysfurniture.en.alibaba.com/",
        "",
        "Lecong / export furniture",
    ),
    (
        "auto_parts",
        "Guangzhou Lima Electronic Technology Co., Ltd.",
        "https://lemaban.en.alibaba.com/",
        "",
        "Auto lights; SGS onsite",
    ),
    (
        "auto_parts",
        "Foshan Startec Electronic Technology Co., Ltd.",
        "",
        "http://www.startecinc.com/",
        "LED auto lighting; IATF 16949",
    ),
]:
    add(
        region="China",
        country="CN",
        cat=cat,
        name=name,
        url=url,
        web=web,
        notes=notes,
        pri="P1",
        products=8,
    )

HUBS = {
    "clothing_accessories": ("Guangdong", "apparel manufacturer"),
    "pottery": ("Fujian", "ceramic manufacturer"),
    "woodwork": ("Zhejiang", "wooden products manufacturer"),
    "jewelry": ("Guangdong", "jewelry manufacturer"),
    "agriculture_food": ("Shandong", "food processing manufacturer"),
    "animals_pets": ("Guangdong", "pet products manufacturer"),
    "apparel_footwear": ("Fujian", "shoe manufacturer"),
    "auto_parts": ("Zhejiang", "auto parts manufacturer"),
    "beauty_personal_care": ("Guangdong", "cosmetics manufacturer"),
    "building_materials": ("Hebei", "building materials manufacturer"),
    "chemicals": ("Jiangsu", "chemical manufacturer"),
    "consumer_electronics": ("Shenzhen", "electronics manufacturer"),
    "electrical_equipment": ("Zhejiang", "electrical equipment manufacturer"),
    "energy_solar": ("Jiangsu", "solar panel manufacturer"),
    "environment_recycling": ("Guangdong", "recycling equipment manufacturer"),
    "fabric_textiles": ("Zhejiang", "textile fabric manufacturer"),
    "furniture": ("Foshan", "furniture manufacturer"),
    "gifts_crafts": ("Yiwu", "gifts crafts manufacturer"),
    "hardware_tools": ("Yongkang", "tools manufacturer"),
    "health_medical": ("Jiangsu", "medical supplies manufacturer"),
    "home_garden": ("Zhejiang", "home garden manufacturer"),
    "industrial_machinery": ("Shanghai", "industrial machinery manufacturer"),
    "it_software": ("Shenzhen", "software SaaS B2B"),
    "lighting": ("Zhongshan", "LED lighting manufacturer"),
    "luggage_bags": ("Guangzhou", "luggage bags manufacturer"),
    "metals_minerals": ("Hebei", "metal products manufacturer"),
    "office_school": ("Ningbo", "office supplies manufacturer"),
    "packaging_printing": ("Wenzhou", "packaging manufacturer"),
    "plastic_rubber": ("Dongguan", "plastic rubber manufacturer"),
    "security_protection": ("Shenzhen", "security equipment manufacturer"),
    "sports_outdoors": ("Fujian", "sports outdoor manufacturer"),
    "toys_kids": ("Shantou", "toys manufacturer"),
    "transportation": ("Chongqing", "electric scooter manufacturer"),
    "telecom": ("Shenzhen", "telecom equipment manufacturer"),
    "services_b2b": ("Shanghai", "B2B manufacturing services"),
}

for cat, (hub, q) in HUBS.items():
    q_enc = q.replace(" ", "+")
    search = (
        "https://www.alibaba.com/trade/search?fsb=y&IndexArea=company_en"
        f"&SearchText={q_enc}"
    )
    for i in range(1, 4):
        add(
            region="China",
            country="CN",
            cat=cat,
            name=f"[Pick Verified #{i}] {hub} — {q}",
            src="alibaba_search_target",
            url=search,
            notes=(
                f"Alibaba: Verified Supplier + Trade Assurance + Manufacturer. "
                f"Hub: {hub}. Confirm factory, then ask listing permission."
            ),
            pri="P2",
            products=5,
        )

# --- CIS named + find targets ---
for country, cat, name, url, web, notes in [
    ("UZ", "fabric_textiles", "Uztex Group", "", "https://uztexgroup.com/", "Cotton textile full cycle"),
    ("UZ", "fabric_textiles", "FAYZ-M", "", "https://fayzm.uz/about", "Textile cluster; export EU/CIS"),
    ("UZ", "fabric_textiles", "Sharq Textile Group", "", "https://en.stg.com.uz/", "Samarkand full cycle"),
    (
        "UZ",
        "clothing_accessories",
        "Parvoz Xumo Ravnaq Trans LLC (Haj Tex)",
        "",
        "https://www.betterwork.org/uzbekistan/participating-factories-and-manufacturers-in-uzbekistan/",
        "Better Work list",
    ),
    (
        "UZ",
        "clothing_accessories",
        "Jizzakh Toshtepa Textile (JTT)",
        "",
        "https://www.betterwork.org/uzbekistan/participating-factories-and-manufacturers-in-uzbekistan/",
        "Full garment cycle",
    ),
    (
        "UZ",
        "clothing_accessories",
        "Mirismoil Tex Invest",
        "",
        "https://www.betterwork.org/uzbekistan/participating-factories-and-manufacturers-in-uzbekistan/",
        "Knit fabrics & garments",
    ),
    ("UZ", "clothing_accessories", "Irodat Textile", "", "https://textilepages.com/uzbekistan/apparel-garments-suppliers", "Tashkent sewing"),
    ("UZ", "clothing_accessories", "SAAS TEKS INVEST LLC", "", "https://textilepages.com/uzbekistan/apparel-garments-suppliers", "Knitted products"),
    ("UZ", "clothing_accessories", "Premier Raiments", "", "https://textilepages.com/uzbekistan/apparel-garments-suppliers", "Samarkand knitwear"),
    ("UZ", "clothing_accessories", "Kristall Tekstil Libos", "", "https://textilepages.com/uzbekistan/apparel-garments-suppliers", "Namangan suits"),
    ("KZ", "building_materials", "ТОО АЗМК", "", "https://www.azmk.kz/", "Metal / bridge structures"),
    ("KZ", "building_materials", "Metall Profil Shymkent", "", "https://shimkent.metallprofil.kz/about/", "Roofing / sandwich panels"),
    ("KZ", "agriculture_food", "Royal Food LLP", "", "https://damu.kz/", "Seasonings — Damu exporters catalog"),
    ("KZ", "agriculture_food", "Shin-Line", "", "https://damu.kz/", "Ice cream / dairy exporter"),
    ("KZ", "agriculture_food", "APK Damu Agro LLP", "", "https://damu.kz/", "Cotton processing"),
    ("KZ", "building_materials", "Makinsky Thermal Insulation (MakWool)", "", "https://damu.kz/", "Basalt insulation"),
    ("KZ", "building_materials", "KMK Group Corporation", "", "https://kazbuild.kz/", "Sheet metal"),
    ("KZ", "building_materials", "Polimermetall-T", "", "https://kazbuild.kz/", "Sandwich panels"),
    ("KZ", "metals_minerals", "Shymkent Temir / AsiaMetcom", "", "https://damu.kz/", "Verify legal name in Damu catalog"),
    ("KZ", "electrical_equipment", "Kazelektromash", "", "https://damu.kz/", "Confirm via Damu exporters 2024"),
    ("BY", "metals_minerals", "BMZ (Belarusian Steel Works)", "", "https://belsteel.com/", "Steel / rebar / pipes"),
    ("BY", "building_materials", "Keramin", "", "https://www.keramin.by/", "Ceramic tiles"),
    ("BY", "building_materials", "Rolforming", "", "https://kazbuild.kz/", "Metal products — KazBuild exhibitor"),
    ("BY", "building_materials", "ProfGypsBel", "", "https://kazbuild.kz/", "Gypsum"),
    ("BY", "industrial_machinery", "DEMZ / Docke Asia", "", "https://kazbuild.kz/", "Construction materials equipment"),
    ("RU", "building_materials", "Metall Profil", "", "https://www.metallprofil.ru/", "Roofing CIS"),
    ("RU", "building_materials", "Tagil Steel", "", "https://kazbuild.kz/", "Metal structures"),
    ("RU", "building_materials", "Mayakmetall", "", "https://kazbuild.kz/", "Polymer building materials"),
    ("RU", "building_materials", "Profholod", "", "https://kazbuild.kz/", "Sandwich panels"),
    ("RU", "industrial_machinery", "Stroymehanika", "", "https://kazbuild.kz/", "Construction equipment"),
]:
    add(
        region="CIS",
        country=country,
        cat=cat,
        name=name,
        url=url,
        web=web,
        notes=notes,
        src="named_company",
        via="Website / email / export department",
        pri="P1",
        products=5,
    )

for country, extras in {
    "UZ": [
        ("agriculture_food", "food dried fruit"),
        ("building_materials", "cement brick"),
        ("chemicals", "fertilizer"),
        ("home_garden", "home textile"),
    ],
    "KZ": [
        ("chemicals", "chemical"),
        ("furniture", "furniture"),
        ("plastic_rubber", "plastic"),
        ("packaging_printing", "packaging"),
    ],
    "RU": [
        ("agriculture_food", "food manufacturer"),
        ("furniture", "furniture factory"),
        ("auto_parts", "auto parts"),
        ("chemicals", "chemical plant"),
        ("health_medical", "medical supplies"),
    ],
    "BY": [
        ("agriculture_food", "food dairy"),
        ("furniture", "furniture"),
        ("plastic_rubber", "plastic"),
        ("electrical_equipment", "electrical"),
        ("chemicals", "chemical"),
    ],
    "KG": [
        ("building_materials", "building"),
        ("agriculture_food", "honey dried fruit"),
        ("clothing_accessories", "garment"),
        ("home_garden", "felt"),
        ("metals_minerals", "metal"),
        ("fabric_textiles", "textile"),
    ],
    "TJ": [
        ("agriculture_food", "cotton dried fruit"),
        ("building_materials", "building"),
        ("clothing_accessories", "garment"),
        ("home_garden", "carpet"),
        ("metals_minerals", "aluminum"),
        ("fabric_textiles", "textile"),
    ],
    "AZ": [
        ("agriculture_food", "food hazelnut"),
        ("building_materials", "building"),
        ("chemicals", "chemical"),
        ("metals_minerals", "metal"),
        ("clothing_accessories", "garment"),
    ],
    "AM": [
        ("agriculture_food", "dried fruit"),
        ("jewelry", "jewelry"),
        ("building_materials", "building"),
        ("clothing_accessories", "garment"),
        ("gifts_crafts", "crafts"),
    ],
    "MD": [
        ("agriculture_food", "wine food"),
        ("agriculture_food", "dried fruit nuts"),
        ("building_materials", "building"),
        ("clothing_accessories", "garment"),
        ("furniture", "furniture"),
    ],
}.items():
    for cat, q in extras:
        q_enc = f"{country}+{q.replace(' ', '+')}"
        add(
            region="CIS",
            country=country,
            cat=cat,
            name=f"[Find] {country} — {q} manufacturer/exporter",
            src="alibaba_search_target",
            url=(
                "https://www.alibaba.com/trade/search?fsb=y&IndexArea=company_en"
                f"&SearchText={q_enc}"
            ),
            notes="Confirm company website; contact export manager for AnyLang listing consent.",
            via="Website / email / LinkedIn / export dept",
            pri="P2",
            products=5,
        )

for i, r in enumerate(rows, 1):
    r["id"] = f"M{i:03d}"

OUT.parent.mkdir(parents=True, exist_ok=True)
fields = list(rows[0].keys())
with OUT.open("w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(rows)

named = sum(1 for r in rows if r["source_type"] == "named_company")
search = sum(1 for r in rows if r["source_type"] == "alibaba_search_target")
cn = sum(1 for r in rows if r["region"] == "China")
cis = sum(1 for r in rows if r["region"] == "CIS")
print(f"Wrote {OUT}")
print(f"total={len(rows)} named={named} search_targets={search} china={cn} cis={cis}")
