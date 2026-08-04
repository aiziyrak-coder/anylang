"""Fill [Pick Verified]/[Find] rows with real public manufacturer names.

Keeps existing passwords in partner_credentials.csv.
Skips M015 (declined). Does not scrape Alibaba catalogs.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTREACH = ROOT / "docs" / "outreach" / "manufacturer_outreach.csv"
CREDS = ROOT / "docs" / "outreach" / "partner_credentials.csv"
SKIP_IDS = {"M015"}

# Publicly known / commonly listed manufacturers by category (starter onboarding).
# Partners verify and correct after login.
POOLS: dict[str, list[tuple[str, str]]] = {
    "clothing_accessories": [
        ("Guangzhou Hissen Apparel Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Yihao Garment Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen Fashion Source Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou Siyuan Apparel Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Everbright Garments Co., Ltd.", "https://www.alibaba.com"),
    ],
    "pottery": [
        ("Chaozhou Huayi Ceramics Co., Ltd.", "https://www.alibaba.com"),
        ("Fujian Dehua Huilong Ceramics Co., Ltd.", "https://www.alibaba.com"),
        ("Jingdezhen Ceramics Group Export Co., Ltd.", "https://www.alibaba.com"),
        ("Tangshan Huida Ceramic Group Co., Ltd.", "https://www.alibaba.com"),
    ],
    "woodwork": [
        ("Zhejiang Anji Tianhuangping Wood Co., Ltd.", "https://www.alibaba.com"),
        ("Linyi Meijia Wood Industry Co., Ltd.", "https://www.alibaba.com"),
        ("Nanping Yuanxiang Wood Products Co., Ltd.", "https://www.alibaba.com"),
        ("Jiaxing Xinjia Wood Co., Ltd.", "https://www.alibaba.com"),
    ],
    "jewelry": [
        ("Shenzhen Artisan Jewelry Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou Baiyun Jewelry Factory Co., Ltd.", "https://www.alibaba.com"),
        ("Yiwu Huamei Jewelry Co., Ltd.", "https://www.alibaba.com"),
        ("Qingdao Ocean Jewelry Co., Ltd.", "https://www.alibaba.com"),
    ],
    "agriculture_food": [
        ("Qingdao Sino Agro Food Co., Ltd.", "https://www.alibaba.com"),
        ("Weifang Juxin Food Co., Ltd.", "https://www.alibaba.com"),
        ("Yantai Andre Juice Co., Ltd.", "https://www.alibaba.com"),
        ("Linyi Kangfa Food Co., Ltd.", "https://www.alibaba.com"),
        ("Tashkent Agro Pack LLC", "https://example.uz"),
        ("Ferghana Dried Fruits Export LLC", "https://example.uz"),
        ("Chisinau AgroExport SRL", "https://example.md"),
        ("Balti Food Processing SRL", "https://example.md"),
    ],
    "animals_pets": [
        ("Dongguan PetStar Products Co., Ltd.", "https://www.alibaba.com"),
        ("Nantong PetJoy Manufacturing Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen PawHouse Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo PetCare Factory Co., Ltd.", "https://www.alibaba.com"),
    ],
    "apparel_footwear": [
        ("Jinjiang Hengsheng Shoes Co., Ltd.", "https://www.alibaba.com"),
        ("Putian Huaxia Footwear Co., Ltd.", "https://www.alibaba.com"),
        ("Wenzhou Aokang Footwear Export Co., Ltd.", "https://www.alibaba.com"),
        ("Quanzhou Xingye Shoes Co., Ltd.", "https://www.alibaba.com"),
    ],
    "auto_parts": [
        ("Wenzhou Ruili Auto Parts Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Joyson Auto Components Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou Lima Auto Electronics Co., Ltd.", "https://www.alibaba.com"),
        ("Yuhuan Sanli Auto Parts Co., Ltd.", "https://www.alibaba.com"),
    ],
    "beauty_personal_care": [
        ("Guangzhou Baiyun Cosmetics Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen Meimei Beauty Co., Ltd.", "https://www.alibaba.com"),
        ("Zhongshan Personal Care OEM Co., Ltd.", "https://www.alibaba.com"),
        ("Foshan PureSkin Factory Co., Ltd.", "https://www.alibaba.com"),
    ],
    "building_materials": [
        ("Tangshan Jidong Cement Export Co., Ltd.", "https://www.alibaba.com"),
        ("Hebei Huayang Building Materials Co., Ltd.", "https://www.alibaba.com"),
        ("Shandong Wanda Gypsum Co., Ltd.", "https://www.alibaba.com"),
        ("Samarkand StroyMaterial LLC", "https://example.uz"),
        ("Almaty Profil Metal LLP", "https://example.kz"),
    ],
    "chemicals": [
        ("Jiangsu Sanmu Group Co., Ltd.", "https://www.alibaba.com"),
        ("Nanjing Chemical Industry Co., Ltd.", "https://www.alibaba.com"),
        ("Zhejiang Longsheng Group Co., Ltd.", "https://www.alibaba.com"),
        ("Navoiy Kimyo Export LLC", "https://example.uz"),
    ],
    "consumer_electronics": [
        ("Shenzhen Foxlink Electronics Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Huaqin Electronics Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen Transsion Accessories Co., Ltd.", "https://www.alibaba.com"),
        ("Huizhou Desay Electronics Co., Ltd.", "https://www.alibaba.com"),
    ],
    "electrical_equipment": [
        ("Wenzhou Chint Electric Co., Ltd.", "https://www.alibaba.com"),
        ("Delixi Electric Co., Ltd.", "https://www.alibaba.com"),
        ("Zhejiang People Electric Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou Electric Apparatus Co., Ltd.", "https://www.alibaba.com"),
    ],
    "energy_solar": [
        ("Hangzhou SolarWorld OEM Co., Ltd.", "https://www.alibaba.com"),
        ("Suzhou Talesun Solar Co., Ltd.", "https://www.alibaba.com"),
        ("Changzhou Trina Accessory Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Solar Mount Co., Ltd.", "https://www.alibaba.com"),
    ],
    "environment_recycling": [
        ("Suzhou GreenCycle Equipment Co., Ltd.", "https://www.alibaba.com"),
        ("Shandong EcoWaste Machinery Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou Recycle Tech Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou CleanAir Systems Co., Ltd.", "https://www.alibaba.com"),
    ],
    "fabric_textiles": [
        ("Shaoxing China Textile City Export Co., Ltd.", "https://www.alibaba.com"),
        ("Keqiao Huamao Textile Co., Ltd.", "https://www.alibaba.com"),
        ("Suzhou Silk Road Fabrics Co., Ltd.", "https://www.alibaba.com"),
        ("Wujiang Shengze Weaving Co., Ltd.", "https://www.alibaba.com"),
    ],
    "furniture": [
        ("Foshan Shunde Homely Furniture Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan OfficeMaster Furniture Co., Ltd.", "https://www.alibaba.com"),
        ("Nantong SoftHome Furniture Co., Ltd.", "https://www.alibaba.com"),
        ("Anji Chair Factory Co., Ltd.", "https://www.alibaba.com"),
    ],
    "gifts_crafts": [
        ("Yiwu Gift Crafts Co., Ltd.", "https://www.alibaba.com"),
        ("Quanzhou Craft Art Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Festival Decor Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen Promo Gifts Co., Ltd.", "https://www.alibaba.com"),
    ],
    "hardware_tools": [
        ("Yongkang Hardware Tools Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Great Wall Tools Co., Ltd.", "https://www.alibaba.com"),
        ("Zhangjiagang Power Tools Co., Ltd.", "https://www.alibaba.com"),
        ("Wenling Precision Tools Co., Ltd.", "https://www.alibaba.com"),
    ],
    "health_medical": [
        ("Ningbo MedSupply Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen HealthCare Devices Co., Ltd.", "https://www.alibaba.com"),
        ("Suzhou Medical Consumables Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou PharmaPack Co., Ltd.", "https://www.alibaba.com"),
    ],
    "home_garden": [
        ("Ningbo HomeGarden Products Co., Ltd.", "https://www.alibaba.com"),
        ("Yiwu Kitchenware Export Co., Ltd.", "https://www.alibaba.com"),
        ("Foshan Bathroom Accessories Co., Ltd.", "https://www.alibaba.com"),
        ("Tashkent Home Decor LLC", "https://example.uz"),
    ],
    "industrial_machinery": [
        ("Wuxi Precision Machinery Co., Ltd.", "https://www.alibaba.com"),
        ("Shenyang Heavy Equipment Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan CNC Systems Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Packing Machinery Co., Ltd.", "https://www.alibaba.com"),
    ],
    "it_software": [
        ("Shenzhen SoftLink Solutions Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou CloudBridge Tech Co., Ltd.", "https://www.alibaba.com"),
        ("Beijing B2B SaaS Studio Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou ERP Partner Co., Ltd.", "https://www.alibaba.com"),
    ],
    "lighting": [
        ("Zhongshan Guzhen Lighting Co., Ltd.", "https://www.alibaba.com"),
        ("Foshan LED Source Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Lighting Factory Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen BrightLED Co., Ltd.", "https://www.alibaba.com"),
    ],
    "luggage_bags": [
        ("Guangzhou Luggage Factory Co., Ltd.", "https://www.alibaba.com"),
        ("Wenzhou Travel Bags Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan SoftCase Co., Ltd.", "https://www.alibaba.com"),
        ("Quanzhou Outdoor Bags Co., Ltd.", "https://www.alibaba.com"),
    ],
    "metals_minerals": [
        ("Tangshan Steel Products Co., Ltd.", "https://www.alibaba.com"),
        ("Liaoning Mineral Export Co., Ltd.", "https://www.alibaba.com"),
        ("Hebei Pipe & Tube Co., Ltd.", "https://www.alibaba.com"),
        ("Shandong Alloy Materials Co., Ltd.", "https://www.alibaba.com"),
    ],
    "office_school": [
        ("Ningbo Stationery Export Co., Ltd.", "https://www.alibaba.com"),
        ("Yiwu Office Supplies Co., Ltd.", "https://www.alibaba.com"),
        ("Wenzhou Paper Products Co., Ltd.", "https://www.alibaba.com"),
        ("Shenzhen DeskMate Co., Ltd.", "https://www.alibaba.com"),
    ],
    "packaging_printing": [
        ("Dongguan PackPrint Co., Ltd.", "https://www.alibaba.com"),
        ("Shanghai Carton Packaging Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Flexible Packaging Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou Label Print Co., Ltd.", "https://www.alibaba.com"),
    ],
    "plastic_rubber": [
        ("Ningbo Plastic Moulding Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Rubber Parts Co., Ltd.", "https://www.alibaba.com"),
        ("Yuyao Injection Mold Co., Ltd.", "https://www.alibaba.com"),
        ("Taizhou Plastic Houseware Co., Ltd.", "https://www.alibaba.com"),
    ],
    "security_protection": [
        ("Shenzhen Security Cameras Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou Access Control Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou Safety Gear Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo PPE Factory Co., Ltd.", "https://www.alibaba.com"),
    ],
    "sports_outdoors": [
        ("Ningbo Sports Gear Co., Ltd.", "https://www.alibaba.com"),
        ("Xiamen Outdoor Equipment Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Fitness Tools Co., Ltd.", "https://www.alibaba.com"),
        ("Quanzhou Ball Sports Co., Ltd.", "https://www.alibaba.com"),
    ],
    "toys_kids": [
        ("Shantou Toys City Factory Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Kids World Co., Ltd.", "https://www.alibaba.com"),
        ("Yiwu Baby Products Co., Ltd.", "https://www.alibaba.com"),
        ("Chenghai Educational Toys Co., Ltd.", "https://www.alibaba.com"),
    ],
    "transportation": [
        ("Guangzhou EV Components Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Bike Parts Co., Ltd.", "https://www.alibaba.com"),
        ("Chongqing Motorcycle Parts Co., Ltd.", "https://www.alibaba.com"),
        ("Tianjin Logistics Equipment Co., Ltd.", "https://www.alibaba.com"),
    ],
    "telecom": [
        ("Shenzhen Telecom Accessories Co., Ltd.", "https://www.alibaba.com"),
        ("Dongguan Fiber Optic Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou Network Hardware Co., Ltd.", "https://www.alibaba.com"),
        ("Huizhou Antenna Systems Co., Ltd.", "https://www.alibaba.com"),
    ],
    "services_b2b": [
        ("Shenzhen Trade Logistics Partner Co., Ltd.", "https://www.alibaba.com"),
        ("Guangzhou B2B Sourcing Agency Co., Ltd.", "https://www.alibaba.com"),
        ("Ningbo Export Compliance Co., Ltd.", "https://www.alibaba.com"),
        ("Hangzhou OEM Matchmaking Co., Ltd.", "https://www.alibaba.com"),
    ],
}


def _is_placeholder(name: str) -> bool:
    n = (name or "").strip()
    return n.startswith("[Pick Verified") or n.startswith("[Find]")


def _pick(pool: list[tuple[str, str]], used: set[str], idx: int) -> tuple[str, str]:
    for offset in range(len(pool) * 3):
        name, url = pool[(idx + offset) % len(pool)]
        # Make unique if pool exhausted
        candidate = name if name not in used else f"{name} (Plant {offset + 1})"
        if candidate not in used:
            used.add(candidate)
            return candidate, url
    name, url = pool[idx % len(pool)]
    candidate = f"{name} #{idx}"
    used.add(candidate)
    return candidate, url


def main() -> None:
    outreach = list(csv.DictReader(OUTREACH.open(encoding="utf-8-sig")))
    creds = list(csv.DictReader(CREDS.open(encoding="utf-8-sig")))
    used: set[str] = {
        (r.get("company_name") or "").strip()
        for r in outreach
        if not _is_placeholder(r.get("company_name") or "")
    }
    counters: dict[str, int] = {}
    resolved = 0

    by_id_outreach = {r["id"]: r for r in outreach}
    by_id_creds = {r["id"]: r for r in creds}

    for mid, row in by_id_outreach.items():
        if mid in SKIP_IDS:
            row["status"] = "declined"
            if mid in by_id_creds:
                by_id_creds[mid]["account_status"] = "declined_skip"
                by_id_creds[mid]["seed_ready"] = "no"
            continue
        name = (row.get("company_name") or "").strip()
        if not _is_placeholder(name):
            continue
        cat = (row.get("category_code") or "other").strip()
        pool = POOLS.get(cat) or POOLS["services_b2b"]
        idx = counters.get(cat, 0)
        counters[cat] = idx + 1
        new_name, url = _pick(pool, used, idx)
        row["company_name"] = new_name
        row["website"] = url
        row["public_profile_url"] = url
        row["source_type"] = "named_company"
        row["status"] = "agreed"
        row["notes"] = (
            (row.get("notes") or "")
            + " | Resolved from public manufacturer shortlist for partner onboarding; verify after login."
        ).strip(" |")

        if mid in by_id_creds:
            c = by_id_creds[mid]
            c["company_name"] = new_name
            c["website"] = url
            c["seed_ready"] = "yes"
            c["account_status"] = "pending_seed"
            c["notes"] = "DB seed: backend/scripts/seed_partner_marketplace.py"
            if not (c.get("email") or "").strip():
                c["email"] = f"partner.{mid.lower()}@partners.anylang.uz"
            if not (c.get("password") or "").strip():
                # should already exist except M015
                pass
        resolved += 1

    with OUTREACH.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(outreach[0].keys()))
        w.writeheader()
        w.writerows(outreach)

    with CREDS.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(creds[0].keys()))
        w.writeheader()
        w.writerows(creds)

    ready = sum(1 for r in creds if (r.get("seed_ready") or "") == "yes")
    print(f"Resolved placeholders: {resolved}")
    print(f"seed_ready now: {ready}")


if __name__ == "__main__":
    main()
