"""Seed partner business accounts + starter product catalogs into local/prod DB.

Sources:
  docs/outreach/partner_credentials.csv  (seed_ready=yes only; skips M015)
Products:
  Category templates customized per company (not Alibaba scrap).
  Partners verify price/MOQ/images after login.

Usage:
  cd backend
  python -m scripts.seed_partner_marketplace --dry-run
  python -m scripts.seed_partner_marketplace
  python -m scripts.seed_partner_marketplace --products-only
  python -m scripts.seed_partner_marketplace --per-company 20
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import hashlib
import sys
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import get_session_factory
from app.models.product import Product, ProductImage
from app.models.user import BusinessProfile, Subscription, User
from app.services.numbers import assign_random_standard_number

def _creds_path() -> Path:
    import os

    env = (os.environ.get("PARTNER_CREDS_CSV") or "").strip()
    if env:
        return Path(env)
    here = Path(__file__).resolve().parent
    for cand in (
        here.parents[2] / "docs" / "outreach" / "partner_credentials.csv",  # monorepo
        here.parents[1] / "docs" / "outreach" / "partner_credentials.csv",  # /app
        Path("/tmp/partner_credentials.csv"),
    ):
        if cand.exists():
            return cand
    return here.parents[2] / "docs" / "outreach" / "partner_credentials.csv"


CREDS = _creds_path()

# name, short, description template, price_usd, moq, attrs
TEMPLATES: dict[str, list[dict]] = {
    "fabric_textiles": [
        {"name": "Polyester chiffon fabric", "short": "Lightweight chiffon for dresses", "desc": "100% polyester chiffon, soft drape, dyeable. Factory roll goods.", "price": 1.85, "moq": "1000 m", "attrs": [("Width", "150 cm"), ("Weight", "75 gsm")]},
        {"name": "Satin lining fabric", "short": "Smooth satin for lining", "desc": "Acetate/poly satin lining, consistent color lots.", "price": 2.40, "moq": "800 m", "attrs": [("Width", "140 cm"), ("Finish", "Soft")]},
        {"name": "Knitted jersey fabric", "short": "Single jersey for apparel", "desc": "Cotton/poly jersey, good stretch recovery.", "price": 3.10, "moq": "500 kg", "attrs": [("Composition", "60/40"), ("GSM", "180")]},
        {"name": "Home textile sheeting", "short": "Bed sheet greige/finished", "desc": "Percale and satin sheeting for hospitality OEMs.", "price": 4.20, "moq": "2000 m", "attrs": [("Thread count", "200TC"), ("Width", "250 cm")]},
        {"name": "Twill workwear fabric", "short": "Durable twill for uniforms", "desc": "TC twill with optional water repellent finish.", "price": 2.95, "moq": "1000 m", "attrs": [("Composition", "65/35"), ("Weight", "240 gsm")]},
        {"name": "Mesh sports fabric", "short": "Breathable sports mesh", "desc": "Polyester mesh for sportswear and bags.", "price": 2.15, "moq": "600 m", "attrs": [("Width", "160 cm"), ("Type", "Warp knit")]},
        {"name": "Denim fabric rolls", "short": "Indigo denim for jeans", "desc": "Mid-weight denim for jeans/OEM programs.", "price": 3.80, "moq": "3000 m", "attrs": [("Weight", "12 oz"), ("Selvedge", "No")]},
        {"name": "Fleece knitted fabric", "short": "Polar fleece for outerwear", "desc": "Anti-pilling polar fleece, custom colors.", "price": 2.70, "moq": "500 kg", "attrs": [("GSM", "280"), ("Brush", "Double")]},
        {"name": "Printed chiffon", "short": "Digital print chiffon", "desc": "Custom digital print on chiffon, sampling available.", "price": 3.50, "moq": "300 m", "attrs": [("Print", "Digital"), ("Width", "145 cm")]},
        {"name": "Interlining fusible", "short": "Garment fusible interlining", "desc": "Woven/nonwoven fusible for collars and fronts.", "price": 1.20, "moq": "2000 m", "attrs": [("Adhesive", "PES"), ("Width", "112 cm")]},
        {"name": "Lace fabric", "short": "Stretch lace for lingerie", "desc": "Nylon/spandex lace, multiple designs.", "price": 4.60, "moq": "400 m", "attrs": [("Width", "150 cm"), ("Stretch", "Yes")]},
        {"name": "Canvas fabric", "short": "Cotton canvas for bags", "desc": "Heavy canvas for tote/work bags.", "price": 2.55, "moq": "1000 m", "attrs": [("Weight", "320 gsm"), ("Finish", "Plain")]},
        {"name": "Organza fabric", "short": "Sheer organza for decor", "desc": "Polyester organza for bridal and packaging.", "price": 1.65, "moq": "500 m", "attrs": [("Width", "150 cm"), ("Sheer", "High")]},
        {"name": "Rib knit fabric", "short": "1x1 / 2x2 rib", "desc": "Rib fabric for cuffs, collars, trim.", "price": 3.25, "moq": "300 kg", "attrs": [("Type", "2x2"), ("Elastane", "5%")]},
        {"name": "Velvet upholstery", "short": "Soft velvet for furniture", "desc": "Polyester velvet for sofas and headboards.", "price": 5.40, "moq": "500 m", "attrs": [("Width", "140 cm"), ("Pile", "Cut")]},
        {"name": "Nonwoven interlining", "short": "Nonwoven for apparel", "desc": "PES nonwoven, multiple weights.", "price": 0.85, "moq": "5000 m", "attrs": [("Weight", "40 gsm"), ("Bond", "Thermal")]},
        {"name": "Terry towel fabric", "short": "Cotton terry for towels", "desc": "Loop terry greige/finished for home textiles.", "price": 4.90, "moq": "1000 kg", "attrs": [("Cotton", "100%"), ("GSM", "400")]},
        {"name": "Oxford shirt fabric", "short": "Oxford for shirts", "desc": "Cotton oxford, yarn-dyed options.", "price": 3.60, "moq": "800 m", "attrs": [("Width", "150 cm"), ("Finish", "Peach")]},
        {"name": "Coated outdoor fabric", "short": "PU coated outdoor cloth", "desc": "Waterproof coated fabric for tents/covers.", "price": 3.95, "moq": "1000 m", "attrs": [("Coating", "PU"), ("Waterproof", "Yes")]},
        {"name": "Spandex blend fabric", "short": "4-way stretch fabric", "desc": "Stretch woven/knit for activewear.", "price": 4.10, "moq": "400 m", "attrs": [("Stretch", "4-way"), ("GSM", "220")]},
    ],
    "energy_solar": [
        {"name": "Mono solar module 550W", "short": "High-efficiency mono panel", "desc": "550W monocrystalline module for commercial rooftops.", "price": 95.0, "moq": "20 pcs", "attrs": [("Power", "550W"), ("Cell", "Mono")]},
        {"name": "Poly solar module 330W", "short": "Cost-effective poly panel", "desc": "330W polycrystalline for residential projects.", "price": 62.0, "moq": "50 pcs", "attrs": [("Power", "330W"), ("Cell", "Poly")]},
        {"name": "String inverter 5kW", "short": "On-grid string inverter", "desc": "5kW single-phase on-grid inverter.", "price": 420.0, "moq": "5 pcs", "attrs": [("Power", "5kW"), ("Phase", "1")]},
        {"name": "String inverter 50kW", "short": "Commercial 50kW inverter", "desc": "Three-phase commercial string inverter.", "price": 2800.0, "moq": "2 pcs", "attrs": [("Power", "50kW"), ("Phase", "3")]},
        {"name": "Solar mounting rail kit", "short": "Aluminum roof mount kit", "desc": "Anodized aluminum rails + clamps for pitched roofs.", "price": 38.0, "moq": "100 sets", "attrs": [("Material", "AL6005"), ("Finish", "Anodized")]},
        {"name": "MC4 connector pair", "short": "PV MC4 connectors", "desc": "IP67 MC4 male/female pairs.", "price": 0.85, "moq": "1000 pairs", "attrs": [("IP", "IP67"), ("Cable", "4mm2")]},
        {"name": "Solar cable 4mm2", "short": "UV resistant PV cable", "desc": "TUV-style DC solar cable, red/black.", "price": 0.55, "moq": "5000 m", "attrs": [("Size", "4mm2"), ("Color", "Red/Black")]},
        {"name": "Lithium battery 5kWh", "short": "LFP home storage", "desc": "LiFePO4 wall-mount storage module.", "price": 980.0, "moq": "4 pcs", "attrs": [("Capacity", "5kWh"), ("Chem", "LFP")]},
        {"name": "Charge controller MPPT 60A", "short": "MPPT charge controller", "desc": "60A MPPT for off-grid systems.", "price": 145.0, "moq": "10 pcs", "attrs": [("Current", "60A"), ("Type", "MPPT")]},
        {"name": "LED opto module", "short": "High-power LED module", "desc": "Optoelectronic LED module for lighting OEM.", "price": 4.20, "moq": "500 pcs", "attrs": [("CCT", "4000K"), ("CRI", ">80")]},
        {"name": "Solar street light 60W", "short": "All-in-one street light", "desc": "Integrated solar street light with battery.", "price": 115.0, "moq": "20 pcs", "attrs": [("Power", "60W"), ("Battery", "Li")]},
        {"name": "Microinverter 600W", "short": "Module-level microinverter", "desc": "600W microinverter for balcony/rooftop.", "price": 88.0, "moq": "20 pcs", "attrs": [("Power", "600W"), ("Grid", "On")]},
        {"name": "PV combiner box", "short": "DC combiner with SPD", "desc": "String combiner with fuses and SPD.", "price": 75.0, "moq": "10 pcs", "attrs": [("Inputs", "6"), ("SPD", "Yes")]},
        {"name": "Grounding lug set", "short": "PV grounding accessories", "desc": "Earthing lugs and washers for module frames.", "price": 0.35, "moq": "2000 pcs", "attrs": [("Material", "SS/Cu"), ("Type", "Lug")]},
        {"name": "Flexible solar panel 100W", "short": "ETFE flexible panel", "desc": "Lightweight flexible panel for RV/boats.", "price": 72.0, "moq": "30 pcs", "attrs": [("Power", "100W"), ("Type", "Flexible")]},
        {"name": "Solar water pump kit", "short": "DC solar pump set", "desc": "Agricultural solar pump with controller.", "price": 310.0, "moq": "5 sets", "attrs": [("Head", "40 m"), ("Type", "DC")]},
        {"name": "Monitoring dongle WiFi", "short": "Inverter WiFi stick", "desc": "WiFi monitoring stick for string inverters.", "price": 28.0, "moq": "50 pcs", "attrs": [("Conn", "WiFi"), ("App", "Yes")]},
        {"name": "Bifacial module 580W", "short": "Bifacial mono module", "desc": "Bifacial glass-glass module for utility.", "price": 105.0, "moq": "20 pcs", "attrs": [("Power", "580W"), ("Glass", "G2G")]},
        {"name": "EV charger wallbox 7kW", "short": "AC EV wall charger", "desc": "7kW AC wallbox for residential.", "price": 390.0, "moq": "5 pcs", "attrs": [("Power", "7kW"), ("Conn", "Type2")]},
        {"name": "Solar junction box", "short": "Module junction box", "desc": "IP67 PV module junction box with diodes.", "price": 1.90, "moq": "2000 pcs", "attrs": [("IP", "IP67"), ("Diodes", "3")]},
    ],
    "furniture": [
        {"name": "Office mesh chair", "short": "Ergonomic mesh office chair", "desc": "Adjustable lumbar mesh chair for offices.", "price": 42.0, "moq": "50 pcs", "attrs": [("Frame", "Nylon"), ("Color", "Black")]},
        {"name": "Executive leather chair", "short": "High-back executive chair", "desc": "PU leather executive chair with chrome base.", "price": 78.0, "moq": "30 pcs", "attrs": [("Material", "PU"), ("Base", "Chrome")]},
        {"name": "Conference table 2.4m", "short": "Meeting table set", "desc": "Boardroom table with cable grommets.", "price": 220.0, "moq": "10 pcs", "attrs": [("Length", "2.4 m"), ("Top", "MFC")]},
        {"name": "Sofa 3-seater fabric", "short": "Living room fabric sofa", "desc": "Modern fabric sofa, custom upholstery.", "price": 185.0, "moq": "20 pcs", "attrs": [("Seats", "3"), ("Fill", "Foam")]},
        {"name": "Dining table oak look", "short": "6-seat dining table", "desc": "Oak-look MDF dining table.", "price": 95.0, "moq": "30 pcs", "attrs": [("Seats", "6"), ("Finish", "Oak")]},
        {"name": "Hotel bedside table", "short": "Hospitality nightstand", "desc": "Compact hotel nightstand with drawer.", "price": 28.0, "moq": "100 pcs", "attrs": [("Drawers", "1"), ("Finish", "Melamine")]},
        {"name": "Wardrobe 2-door", "short": "Bedroom wardrobe", "desc": "Two-door wardrobe with hanging rail.", "price": 110.0, "moq": "40 pcs", "attrs": [("Doors", "2"), ("Height", "200 cm")]},
        {"name": "Kids study desk", "short": "Children study desk", "desc": "Height-friendly kids desk with shelf.", "price": 36.0, "moq": "80 pcs", "attrs": [("Age", "6-12"), ("Color", "Multi")]},
        {"name": "Metal bunk bed", "short": "Twin metal bunk bed", "desc": "Powder-coated metal bunk for dorms.", "price": 125.0, "moq": "40 pcs", "attrs": [("Size", "Twin"), ("Finish", "Powder")]},
        {"name": "Outdoor rattan set", "short": "Patio rattan furniture set", "desc": "PE rattan sofa set with cushions.", "price": 210.0, "moq": "15 sets", "attrs": [("Pieces", "4"), ("Material", "PE rattan")]},
        {"name": "Reception desk L-shape", "short": "Lobby reception counter", "desc": "L-shaped reception desk with LED option.", "price": 260.0, "moq": "8 pcs", "attrs": [("Shape", "L"), ("LED", "Optional")]},
        {"name": "Filing cabinet 3-drawer", "short": "Steel filing cabinet", "desc": "Lockable 3-drawer steel cabinet.", "price": 48.0, "moq": "50 pcs", "attrs": [("Drawers", "3"), ("Lock", "Yes")]},
        {"name": "Bar stool wood", "short": "Cafe wood bar stool", "desc": "Solid/wood composite bar stool.", "price": 22.0, "moq": "100 pcs", "attrs": [("Height", "75 cm"), ("Seat", "Wood")]},
        {"name": "TV stand modern", "short": "Media console", "desc": "Modern TV cabinet with cable management.", "price": 68.0, "moq": "40 pcs", "attrs": [("Width", "160 cm"), ("Storage", "Yes")]},
        {"name": "Mattress pocket spring", "short": "Hotel pocket spring mattress", "desc": "Independent pocket spring mattress.", "price": 95.0, "moq": "50 pcs", "attrs": [("Size", "Queen"), ("Spring", "Pocket")]},
        {"name": "Folding banquet chair", "short": "Event folding chair", "desc": "Stackable banquet chair for events.", "price": 14.5, "moq": "200 pcs", "attrs": [("Frame", "Steel"), ("Stack", "Yes")]},
        {"name": "Bookshelf 5-tier", "short": "Open display bookshelf", "desc": "Five-tier open bookshelf.", "price": 39.0, "moq": "60 pcs", "attrs": [("Tiers", "5"), ("Material", "Particle")]},
        {"name": "Dressing table mirror", "short": "Vanity dressing table", "desc": "Dressing table with mirror and drawers.", "price": 72.0, "moq": "40 pcs", "attrs": [("Drawers", "3"), ("Mirror", "Yes")]},
        {"name": "Lounge armchair", "short": "Accent lounge chair", "desc": "Upholstered accent armchair.", "price": 58.0, "moq": "40 pcs", "attrs": [("Style", "Modern"), ("Legs", "Wood")]},
        {"name": "Kitchen cabinet set", "short": "Modular kitchen cabinets", "desc": "Modular kitchen units, custom sizes.", "price": 480.0, "moq": "5 sets", "attrs": [("Style", "Modular"), ("Finish", "Lacquer")]},
    ],
    "auto_parts": [
        {"name": "LED headlight bulb H7", "short": "Automotive LED H7", "desc": "Plug-and-play LED headlight bulbs.", "price": 8.5, "moq": "200 pcs", "attrs": [("Base", "H7"), ("Color", "6000K")]},
        {"name": "Car dash cam 1080p", "short": "Front dash camera", "desc": "1080p dash cam with loop recording.", "price": 18.0, "moq": "100 pcs", "attrs": [("Res", "1080p"), ("GPS", "Optional")]},
        {"name": "Brake pad set", "short": "Ceramic brake pads", "desc": "Low-dust ceramic brake pads for passenger cars.", "price": 12.0, "moq": "200 sets", "attrs": [("Type", "Ceramic"), ("Axle", "Front")]},
        {"name": "Cabin air filter", "short": "OEM-fit cabin filter", "desc": "Activated carbon cabin filter.", "price": 3.2, "moq": "500 pcs", "attrs": [("Type", "Carbon"), ("Fit", "Multi")]},
        {"name": "Car Android head unit", "short": "7\" Android head unit", "desc": "Touchscreen multimedia with CarPlay option.", "price": 65.0, "moq": "50 pcs", "attrs": [("Screen", "7 inch"), ("OS", "Android")]},
        {"name": "OBD2 scanner tool", "short": "Bluetooth OBD2 reader", "desc": "ELM327-style OBD2 diagnostic tool.", "price": 6.5, "moq": "300 pcs", "attrs": [("Conn", "BT"), ("Protocol", "OBD2")]},
        {"name": "Wiper blade set", "short": "All-season wiper blades", "desc": "Beam-style wiper blades multi-size.", "price": 4.8, "moq": "400 sets", "attrs": [("Type", "Beam"), ("Season", "All")]},
        {"name": "Shock absorber", "short": "Gas shock absorber", "desc": "Gas-charged shock for popular models.", "price": 16.0, "moq": "100 pcs", "attrs": [("Type", "Gas"), ("Position", "Rear")]},
        {"name": "Car battery 60Ah", "short": "Maintenance-free battery", "desc": "12V 60Ah MF car battery.", "price": 55.0, "moq": "40 pcs", "attrs": [("Ah", "60"), ("Volt", "12V")]},
        {"name": "USB car charger PD", "short": "PD 30W car charger", "desc": "Dual-port PD/QC car charger.", "price": 3.9, "moq": "500 pcs", "attrs": [("PD", "30W"), ("Ports", "2")]},
        {"name": "Parking sensor kit", "short": "4-sensor parking kit", "desc": "Reverse parking sensors with buzzer.", "price": 11.0, "moq": "100 kits", "attrs": [("Sensors", "4"), ("Display", "Optional")]},
        {"name": "Engine oil filter", "short": "Spin-on oil filter", "desc": "OEM-equivalent spin-on oil filter.", "price": 2.4, "moq": "500 pcs", "attrs": [("Type", "Spin-on"), ("Seal", "NBR")]},
        {"name": "Radiator hose kit", "short": "Silicone hose kit", "desc": "High-temp silicone radiator hoses.", "price": 28.0, "moq": "50 kits", "attrs": [("Material", "Silicone"), ("Temp", "High")]},
        {"name": "TPMS sensor", "short": "Tire pressure sensor", "desc": "Programmable TPMS sensor.", "price": 9.5, "moq": "200 pcs", "attrs": [("Freq", "433MHz"), ("Type", "Clamp")]},
        {"name": "Car floor mat set", "short": "Universal floor mats", "desc": "All-weather rubber floor mats.", "price": 14.0, "moq": "100 sets", "attrs": [("Pcs", "4"), ("Material", "Rubber")]},
        {"name": "HID ballast", "short": "35W HID ballast", "desc": "Digital HID ballast for headlights.", "price": 7.2, "moq": "200 pcs", "attrs": [("Power", "35W"), ("Type", "Digital")]},
        {"name": "Alternator 12V", "short": "Reman/new alternator", "desc": "12V alternator for common engines.", "price": 68.0, "moq": "30 pcs", "attrs": [("Volt", "12V"), ("Amps", "90A")]},
        {"name": "Spark plug iridium", "short": "Iridium spark plugs", "desc": "Long-life iridium spark plugs.", "price": 3.8, "moq": "400 pcs", "attrs": [("Tip", "Iridium"), ("Gap", "OEM")]},
        {"name": "Car horn set", "short": "Dual tone electric horn", "desc": "12V dual-tone horn pair.", "price": 5.5, "moq": "200 sets", "attrs": [("Volt", "12V"), ("Tone", "Dual")]},
        {"name": "ECU diagnostic cable", "short": "Brand diagnostic cable", "desc": "USB diagnostic interface cable.", "price": 22.0, "moq": "50 pcs", "attrs": [("Interface", "USB"), ("Brand", "Multi")]},
    ],
    "clothing_accessories": [
        {"name": "Men cotton T-shirt", "short": "Basic cotton tee OEM", "desc": "180gsm cotton T-shirt, custom print ready.", "price": 2.8, "moq": "500 pcs", "attrs": [("GSM", "180"), ("Fit", "Regular")]},
        {"name": "Women blouse woven", "short": "Office blouse OEM", "desc": "Woven blouse, multiple size runs.", "price": 6.5, "moq": "300 pcs", "attrs": [("Fabric", "Woven"), ("Sizes", "S-XXL")]},
        {"name": "Denim jeans men", "short": "Stretch denim jeans", "desc": "Mid-rise stretch jeans, wash options.", "price": 9.8, "moq": "400 pcs", "attrs": [("Stretch", "Yes"), ("Wash", "Custom")]},
        {"name": "Hoodie fleece", "short": "Pullover fleece hoodie", "desc": "Brushed fleece hoodie with kangaroo pocket.", "price": 7.2, "moq": "400 pcs", "attrs": [("Fleece", "280gsm"), ("Hood", "Yes")]},
        {"name": "Polo shirt pique", "short": "Pique polo OEM", "desc": "Cotton pique polo with custom collar.", "price": 4.5, "moq": "500 pcs", "attrs": [("Fabric", "Pique"), ("Buttons", "3")]},
        {"name": "Sports leggings", "short": "Activewear leggings", "desc": "High-waist sports leggings.", "price": 5.9, "moq": "400 pcs", "attrs": [("Stretch", "4-way"), ("Waist", "High")]},
        {"name": "Kids school uniform set", "short": "Shirt + pants set", "desc": "Durable school uniform program.", "price": 8.4, "moq": "600 sets", "attrs": [("Set", "2 pcs"), ("Age", "6-14")]},
        {"name": "Winter padded jacket", "short": "Quilted winter jacket", "desc": "Lightweight padded jacket.", "price": 14.5, "moq": "300 pcs", "attrs": [("Fill", "Poly"), ("Shell", "Nylon")]},
        {"name": "Baseball cap", "short": "Embroidered cap OEM", "desc": "6-panel cotton cap, embroidery ready.", "price": 1.9, "moq": "1000 pcs", "attrs": [("Panels", "6"), ("Closure", "Velcro")]},
        {"name": "Knit scarf", "short": "Acrylic knit scarf", "desc": "Soft acrylic scarf, custom colors.", "price": 2.2, "moq": "800 pcs", "attrs": [("Material", "Acrylic"), ("Length", "180 cm")]},
        {"name": "Leather belt men", "short": "Genuine/PU belt", "desc": "Dress belt with alloy buckle.", "price": 3.6, "moq": "500 pcs", "attrs": [("Width", "3.5 cm"), ("Buckle", "Alloy")]},
        {"name": "Socks cotton pack", "short": "Crew socks 3-pack", "desc": "Cotton blend crew socks.", "price": 1.4, "moq": "2000 packs", "attrs": [("Pack", "3"), ("Length", "Crew")]},
        {"name": "Workwear coverall", "short": "Industrial coverall", "desc": "TC coverall for factories.", "price": 11.0, "moq": "300 pcs", "attrs": [("Fabric", "TC"), ("Pockets", "Multi")]},
        {"name": "Raincoat PVC", "short": "Reusable raincoat", "desc": "Lightweight PVC raincoat.", "price": 2.5, "moq": "1000 pcs", "attrs": [("Material", "PVC"), ("Hood", "Yes")]},
        {"name": "Swimwear set", "short": "Bikini/swim shorts OEM", "desc": "OEM swimwear with custom prints.", "price": 6.8, "moq": "400 pcs", "attrs": [("Fabric", "Nylon"), ("Print", "Custom")]},
        {"name": "Fashion handbag", "short": "PU fashion tote", "desc": "PU tote bag for retail brands.", "price": 7.5, "moq": "300 pcs", "attrs": [("Material", "PU"), ("Style", "Tote")]},
        {"name": "Thermal underwear set", "short": "Winter base layer", "desc": "Thermal top+bottom set.", "price": 5.5, "moq": "500 sets", "attrs": [("Set", "2"), ("Season", "Winter")]},
        {"name": "Chef uniform jacket", "short": "Kitchen chef coat", "desc": "Double-breasted chef jacket.", "price": 8.9, "moq": "200 pcs", "attrs": [("Buttons", "Snap"), ("Color", "White")]},
        {"name": "Yoga shorts", "short": "High-waist yoga shorts", "desc": "Buttery soft yoga shorts.", "price": 4.2, "moq": "400 pcs", "attrs": [("Waist", "High"), ("Length", "Short")]},
        {"name": "Embroidery patch set", "short": "Custom woven patches", "desc": "Iron-on / sew-on patches.", "price": 0.45, "moq": "5000 pcs", "attrs": [("Type", "Woven"), ("Back", "Iron-on")]},
    ],
    "building_materials": [
        {"name": "Corrugated metal sheet", "short": "Roofing corrugated sheet", "desc": "Galvanized/painted corrugated roofing.", "price": 6.8, "moq": "500 m2", "attrs": [("Coating", "PE"), ("Thickness", "0.45mm")]},
        {"name": "Sandwich panel PIR", "short": "Insulated sandwich panel", "desc": "PIR core sandwich panels for warehouses.", "price": 28.0, "moq": "200 m2", "attrs": [("Core", "PIR"), ("Thick", "100mm")]},
        {"name": "Gypsum board 12mm", "short": "Standard plasterboard", "desc": "12.5mm gypsum board sheets.", "price": 3.2, "moq": "1000 pcs", "attrs": [("Thick", "12.5mm"), ("Size", "1200x2500")]},
        {"name": "Mineral wool slab", "short": "Thermal insulation wool", "desc": "Rock mineral wool slabs.", "price": 4.5, "moq": "200 m3", "attrs": [("Density", "80 kg/m3"), ("Type", "Slab")]},
        {"name": "Profiled steel deck", "short": "Floor decking profile", "desc": "Composite steel decking profiles.", "price": 9.5, "moq": "300 m2", "attrs": [("Profile", "H60"), ("Steel", "S280")]},
        {"name": "PVC window profile", "short": "uPVC extrusion profile", "desc": "Multi-chamber uPVC window profiles.", "price": 2.8, "moq": "5000 m", "attrs": [("Chambers", "5"), ("Color", "White")]},
        {"name": "Ceramic floor tile", "short": "60x60 porcelain tile", "desc": "Porcelain floor tiles for commercial.", "price": 7.5, "moq": "500 m2", "attrs": [("Size", "60x60"), ("PEI", "IV")]},
        {"name": "Rebar steel B500", "short": "Deformed reinforcing bar", "desc": "Construction rebar in bundles.", "price": 520.0, "moq": "20 t", "attrs": [("Grade", "B500"), ("Dia", "12mm")]},
        {"name": "Cement Portland 42.5", "short": "Bagged cement", "desc": "Portland cement 42.5R bags.", "price": 4.8, "moq": "1000 bags", "attrs": [("Grade", "42.5R"), ("Bag", "50kg")]},
        {"name": "Bitumen membrane", "short": "Waterproofing membrane", "desc": "Torch-on bitumen waterproof membrane.", "price": 3.9, "moq": "500 rolls", "attrs": [("Thick", "4mm"), ("Type", "APP")]},
        {"name": "Facade cladding panel", "short": "Aluminum composite panel", "desc": "ACP panels for facades.", "price": 12.0, "moq": "300 m2", "attrs": [("Core", "PE"), ("Thick", "4mm")]},
        {"name": "Drywall metal stud", "short": "CD/UD profile set", "desc": "Galvanized drywall profiles.", "price": 1.1, "moq": "5000 m", "attrs": [("Type", "CD60"), ("Zinc", "Z100")]},
        {"name": "Self-leveling compound", "short": "Floor leveling mix", "desc": "Cementitious self-leveling compound.", "price": 8.5, "moq": "500 bags", "attrs": [("Bag", "25kg"), ("Flow", "High")]},
        {"name": "Facade rockwool", "short": "External wall insulation", "desc": "Facade-grade mineral wool.", "price": 5.8, "moq": "150 m3", "attrs": [("Density", "110"), ("Use", "Facade")]},
        {"name": "Roof tile metal", "short": "Metal roof tile sheet", "desc": "Stone-coated / painted metal tiles.", "price": 8.2, "moq": "400 m2", "attrs": [("Coating", "Stone"), ("Gauge", "0.4")]},
        {"name": "Pipe HDPE PE100", "short": "Pressure HDPE pipe", "desc": "PE100 water pressure pipes.", "price": 2.4, "moq": "5000 m", "attrs": [("SDR", "11"), ("DN", "110")]},
        {"name": "Scaffolding frame", "short": "Steel scaffold frames", "desc": "Hot-dip galvanized scaffold frames.", "price": 35.0, "moq": "100 pcs", "attrs": [("Finish", "HDG"), ("Type", "Frame")]},
        {"name": "Expanding foam sealant", "short": "PU foam can", "desc": "One-component PU foam sealant.", "price": 1.6, "moq": "2000 cans", "attrs": [("Vol", "750ml"), ("Type", "PU")]},
        {"name": "Ceramic sanitary ware", "short": "Washbasin set", "desc": "Ceramic washbasins for projects.", "price": 28.0, "moq": "100 pcs", "attrs": [("Type", "Basin"), ("Color", "White")]},
        {"name": "Thermal break window", "short": "Aluminum thermal window", "desc": "Thermal-break aluminum windows.", "price": 95.0, "moq": "50 pcs", "attrs": [("System", "Thermal"), ("Glass", "Double")]},
    ],
    "agriculture_food": [
        {"name": "Dried apricot grade A", "short": "Sun-dried apricots", "desc": "Export-grade dried apricots, bulk packed.", "price": 3.8, "moq": "1 t", "attrs": [("Grade", "A"), ("Pack", "10kg")]},
        {"name": "Tomato paste 28-30%", "short": "Aseptic tomato paste", "desc": "Concentrated tomato paste in drums/bags.", "price": 820.0, "moq": "5 t", "attrs": [("Brix", "28-30"), ("Pack", "Aseptic")]},
        {"name": "Sunflower oil refined", "short": "Refined sunflower oil", "desc": "Refined sunflower oil in bottles/IBC.", "price": 1.15, "moq": "10 t", "attrs": [("Type", "Refined"), ("Pack", "1L")]},
        {"name": "Wheat flour 1st grade", "short": "Bakery wheat flour", "desc": "First-grade wheat flour for bakeries.", "price": 0.42, "moq": "20 t", "attrs": [("Grade", "1"), ("Pack", "50kg")]},
        {"name": "Frozen berry mix", "short": "IQF berry mix", "desc": "IQF strawberries/raspberries mix.", "price": 2.1, "moq": "5 t", "attrs": [("Process", "IQF"), ("Pack", "10kg")]},
        {"name": "Honey natural bulk", "short": "Natural flower honey", "desc": "Natural honey in drums.", "price": 3.2, "moq": "2 t", "attrs": [("Type", "Floral"), ("Pack", "Drum")]},
        {"name": "Rice long grain", "short": "Long grain white rice", "desc": "Sorted long grain rice for export.", "price": 0.55, "moq": "20 t", "attrs": [("Type", "Long"), ("Broken", "<5%")]},
        {"name": "Pasta durum", "short": "Durum wheat pasta", "desc": "Spaghetti/penne durum pasta OEM.", "price": 0.85, "moq": "5 t", "attrs": [("Wheat", "Durum"), ("Pack", "400g")]},
        {"name": "Dairy milk powder", "short": "Whole milk powder", "desc": "Whole milk powder for food industry.", "price": 3.4, "moq": "5 t", "attrs": [("Fat", "26%"), ("Pack", "25kg")]},
        {"name": "Canned corn", "short": "Sweet corn cans", "desc": "Canned sweet corn for retail/HORECA.", "price": 0.55, "moq": "1 container", "attrs": [("Can", "400g"), ("Brix", "Std")]},
        {"name": "Spice paprika powder", "short": "Sweet paprika powder", "desc": "Ground paprika, ASTA controlled.", "price": 2.8, "moq": "1 t", "attrs": [("ASTA", "120+"), ("Mesh", "40")]},
        {"name": "Bottled drinking water", "short": "PET bottled water", "desc": "0.5L/1.5L drinking water OEM.", "price": 0.12, "moq": "1 container", "attrs": [("Size", "0.5L"), ("Pack", "PET")]},
        {"name": "Juice concentrate apple", "short": "Apple juice concentrate", "desc": "Clear apple juice concentrate.", "price": 1.6, "moq": "5 t", "attrs": [("Brix", "70"), ("Type", "Clear")]},
        {"name": "Animal feed pellet", "short": "Compound feed pellets", "desc": "Livestock compound feed pellets.", "price": 0.35, "moq": "20 t", "attrs": [("Form", "Pellet"), ("Protein", "16%")]},
        {"name": "Nuts walnut kernels", "short": "Shelled walnut kernels", "desc": "Light walnut kernels, export grade.", "price": 6.5, "moq": "1 t", "attrs": [("Color", "Light"), ("Pack", "10kg")]},
        {"name": "Tea black CTC", "short": "Black tea CTC", "desc": "CTC black tea for blending.", "price": 2.4, "moq": "2 t", "attrs": [("Type", "CTC"), ("Grade", "BP")]},
        {"name": "Sugar white refined", "short": "ICUMSA 45 sugar", "desc": "Refined white sugar ICUMSA 45.", "price": 0.52, "moq": "50 t", "attrs": [("ICUMSA", "45"), ("Pack", "50kg")]},
        {"name": "Cheese semi-hard", "short": "Semi-hard cheese blocks", "desc": "Semi-hard cheese for cutting.", "price": 4.8, "moq": "2 t", "attrs": [("Fat", "45%"), ("Form", "Block")]},
        {"name": "Ketchup foodservice", "short": "Tomato ketchup cans", "desc": "Foodservice ketchup in large cans.", "price": 0.95, "moq": "5 t", "attrs": [("Pack", "A10"), ("Brix", "Std")]},
        {"name": "Frozen french fries", "short": "IQF french fries", "desc": "Straight-cut frozen fries.", "price": 0.95, "moq": "10 t", "attrs": [("Cut", "10mm"), ("Pack", "10kg")]},
    ],
    "metals_minerals": [
        {"name": "Hot rolled steel coil", "short": "HRC steel coil", "desc": "Hot-rolled coil for further processing.", "price": 580.0, "moq": "25 t", "attrs": [("Grade", "Q235"), ("Thick", "3mm")]},
        {"name": "Cold rolled steel sheet", "short": "CRC sheets", "desc": "Cold-rolled sheets for fabrication.", "price": 650.0, "moq": "20 t", "attrs": [("Grade", "SPCC"), ("Thick", "1mm")]},
        {"name": "Galvanized steel coil", "short": "GI coil", "desc": "Hot-dip galvanized steel coil.", "price": 720.0, "moq": "20 t", "attrs": [("Zinc", "Z275"), ("Thick", "0.8")]},
        {"name": "Steel wire rod", "short": "Wire rod coils", "desc": "Low carbon wire rod.", "price": 560.0, "moq": "25 t", "attrs": [("Dia", "6.5mm"), ("Grade", "SAE1008")]},
        {"name": "Seamless steel pipe", "short": "Seamless pipe", "desc": "Seamless carbon steel pipe.", "price": 780.0, "moq": "10 t", "attrs": [("Std", "ASTM"), ("OD", "114")]},
        {"name": "Copper cathode", "short": "Grade A copper", "desc": "Electrolytic copper cathode.", "price": 8500.0, "moq": "5 t", "attrs": [("Purity", "99.99"), ("Grade", "A")]},
        {"name": "Aluminum billet", "short": "6063 aluminum billet", "desc": "Extrusion billets 6063.", "price": 2400.0, "moq": "10 t", "attrs": [("Alloy", "6063"), ("Dia", "178")]},
        {"name": "Stainless sheet 304", "short": "SS304 sheet", "desc": "304 stainless steel sheets.", "price": 2100.0, "moq": "5 t", "attrs": [("Grade", "304"), ("Thick", "2mm")]},
        {"name": "Ferroalloy FeSi", "short": "Ferrosilicon 75%", "desc": "FeSi75 for steelmaking.", "price": 1200.0, "moq": "10 t", "attrs": [("Si", "75%"), ("Size", "10-50")]},
        {"name": "Iron ore fines", "short": "Iron ore fines 62%", "desc": "Iron ore fines for sintering.", "price": 95.0, "moq": "1000 t", "attrs": [("Fe", "62%"), ("Type", "Fines")]},
        {"name": "Angle steel", "short": "Equal angle bars", "desc": "Equal angle steel bars.", "price": 590.0, "moq": "20 t", "attrs": [("Size", "50x50"), ("Grade", "Q235")]},
        {"name": "I-beam steel", "short": "Structural I-beams", "desc": "Hot-rolled I-beams.", "price": 610.0, "moq": "20 t", "attrs": [("Size", "IPE200"), ("Grade", "S235")]},
        {"name": "Steel scrap HMS", "short": "HMS 1&2 scrap", "desc": "Heavy melting steel scrap.", "price": 320.0, "moq": "100 t", "attrs": [("Grade", "HMS"), ("Mix", "1&2")]},
        {"name": "Zinc ingot", "short": "SHG zinc ingot", "desc": "Special high grade zinc.", "price": 2800.0, "moq": "5 t", "attrs": [("Purity", "99.995"), ("Form", "Ingot")]},
        {"name": "Lead ingot", "short": "Refined lead", "desc": "Refined lead ingots.", "price": 2100.0, "moq": "5 t", "attrs": [("Purity", "99.97"), ("Form", "Ingot")]},
        {"name": "Titanium dioxide", "short": "TiO2 pigment", "desc": "Rutile TiO2 for coatings.", "price": 2400.0, "moq": "5 t", "attrs": [("Type", "Rutile"), ("Pack", "25kg")]},
        {"name": "Coal anthracite", "short": "Anthracite coal", "desc": "Anthracite for metallurgy/energy.", "price": 140.0, "moq": "500 t", "attrs": [("Fixed C", "High"), ("Size", "Nut")]},
        {"name": "Cast iron manhole", "short": "Ductile iron covers", "desc": "Municipal manhole covers.", "price": 85.0, "moq": "100 pcs", "attrs": [("Class", "D400"), ("Material", "GJS")]},
        {"name": "Welding electrode", "short": "E6013 electrodes", "desc": "General purpose welding rods.", "price": 0.85, "moq": "5 t", "attrs": [("Type", "E6013"), ("Dia", "3.2")]},
        {"name": "Steel grating", "short": "Galvanized grating", "desc": "Bar grating panels.", "price": 28.0, "moq": "200 m2", "attrs": [("Pitch", "30x100"), ("Finish", "HDG")]},
    ],
    "electrical_equipment": [
        {"name": "MCB 1P 16A", "short": "Miniature circuit breaker", "desc": "1P MCB C16 for distribution boards.", "price": 1.2, "moq": "1000 pcs", "attrs": [("Poles", "1P"), ("Amp", "16A")]},
        {"name": "MCCB 3P 250A", "short": "Molded case breaker", "desc": "3P MCCB for industrial panels.", "price": 48.0, "moq": "50 pcs", "attrs": [("Poles", "3P"), ("Amp", "250A")]},
        {"name": "Contactor AC3 25A", "short": "AC contactor", "desc": "AC3 contactor 25A with coil options.", "price": 9.5, "moq": "200 pcs", "attrs": [("AC3", "25A"), ("Coil", "220V")]},
        {"name": "LED panel 600x600", "short": "Office LED panel", "desc": "40W LED panel light.", "price": 12.0, "moq": "200 pcs", "attrs": [("Power", "40W"), ("Size", "600")]},
        {"name": "Distribution board", "short": "Metal DB enclosure", "desc": "Wall-mount distribution board.", "price": 35.0, "moq": "50 pcs", "attrs": [("Ways", "24"), ("IP", "IP40")]},
        {"name": "Cable Cu 3x2.5", "short": "NYM/NYY cable", "desc": "Copper installation cable.", "price": 1.1, "moq": "5000 m", "attrs": [("Cores", "3x2.5"), ("Cu", "Yes")]},
        {"name": "Transformer 100kVA", "short": "Oil distribution transformer", "desc": "100kVA distribution transformer.", "price": 2800.0, "moq": "2 pcs", "attrs": [("kVA", "100"), ("Cooling", "ONAN")]},
        {"name": "UPS 3kVA", "short": "Online UPS", "desc": "Online double-conversion UPS.", "price": 320.0, "moq": "10 pcs", "attrs": [("kVA", "3"), ("Type", "Online")]},
        {"name": "Socket industrial", "short": "CEE industrial socket", "desc": "IP44 industrial sockets.", "price": 4.5, "moq": "200 pcs", "attrs": [("Amp", "32A"), ("Poles", "5")]},
        {"name": "Relay intermediate", "short": "Control relay 8-pin", "desc": "Intermediate control relays.", "price": 1.8, "moq": "500 pcs", "attrs": [("Pins", "8"), ("Coil", "24V")]},
        {"name": "Busbar copper", "short": "Tin-plated copper busbar", "desc": "Copper busbars for panels.", "price": 12.0, "moq": "200 m", "attrs": [("Section", "20x5"), ("Plate", "Tin")]},
        {"name": "Soft starter 37kW", "short": "Motor soft starter", "desc": "Soft starter for pumps/fans.", "price": 210.0, "moq": "10 pcs", "attrs": [("kW", "37"), ("Type", "Soft")]},
        {"name": "VFD 7.5kW", "short": "Variable frequency drive", "desc": "General purpose VFD.", "price": 185.0, "moq": "10 pcs", "attrs": [("kW", "7.5"), ("Phase", "3")]},
        {"name": "LED street light 100W", "short": "Road LED luminaire", "desc": "100W LED street light.", "price": 42.0, "moq": "50 pcs", "attrs": [("Power", "100W"), ("IP", "IP65")]},
        {"name": "Energy meter 3P", "short": "Digital kWh meter", "desc": "Three-phase energy meter.", "price": 18.0, "moq": "100 pcs", "attrs": [("Phase", "3"), ("Display", "LCD")]},
        {"name": "Cable tray perforated", "short": "Steel cable tray", "desc": "Perforated cable tray system.", "price": 8.5, "moq": "500 m", "attrs": [("Width", "200"), ("Finish", "GI")]},
        {"name": "Surge protector SPD", "short": "Type 2 SPD", "desc": "Type 2 surge protective device.", "price": 14.0, "moq": "100 pcs", "attrs": [("Type", "T2"), ("Poles", "4")]},
        {"name": "Generator set 50kVA", "short": "Diesel genset", "desc": "50kVA diesel generator set.", "price": 6500.0, "moq": "1 pcs", "attrs": [("kVA", "50"), ("Fuel", "Diesel")]},
        {"name": "Industrial plug", "short": "CEE industrial plug", "desc": "IP44 industrial plugs.", "price": 3.8, "moq": "200 pcs", "attrs": [("Amp", "32A"), ("Poles", "5")]},
        {"name": "Capacitor bank", "short": "Power factor capacitors", "desc": "PFC capacitor modules.", "price": 55.0, "moq": "20 pcs", "attrs": [("kVAR", "25"), ("Volt", "400")]},
    ],
    "industrial_machinery": [
        {"name": "CNC lathe machine", "short": "Compact CNC lathe", "desc": "Entry CNC lathe for metal shops.", "price": 12500.0, "moq": "1 pcs", "attrs": [("Axis", "2"), ("Chuck", "6 inch")]},
        {"name": "Packaging machine flow", "short": "Flow wrap machine", "desc": "Horizontal flow wrap packaging line.", "price": 7800.0, "moq": "1 pcs", "attrs": [("Speed", "80 ppm"), ("Type", "Flow")]},
        {"name": "Injection molding 160T", "short": "Plastic injection press", "desc": "160 ton injection molding machine.", "price": 28000.0, "moq": "1 pcs", "attrs": [("Ton", "160"), ("Screw", "Std")]},
        {"name": "Air compressor screw", "short": "Screw air compressor", "desc": "Rotary screw compressor 15kW.", "price": 3200.0, "moq": "1 pcs", "attrs": [("kW", "15"), ("Type", "Screw")]},
        {"name": "Laser cutter 1kW", "short": "Fiber laser cutter", "desc": "1kW fiber laser cutting machine.", "price": 22000.0, "moq": "1 pcs", "attrs": [("Power", "1kW"), ("Bed", "3015")]},
        {"name": "Conveyor belt line", "short": "Modular belt conveyor", "desc": "Modular conveyor for factories.", "price": 1800.0, "moq": "1 set", "attrs": [("Length", "10 m"), ("Width", "600")]},
        {"name": "Welding robot cell", "short": "MIG welding robot", "desc": "Compact MIG robot welding cell.", "price": 45000.0, "moq": "1 set", "attrs": [("Process", "MIG"), ("Axes", "6")]},
        {"name": "Hydraulic press 100T", "short": "Shop hydraulic press", "desc": "100 ton H-frame hydraulic press.", "price": 4100.0, "moq": "1 pcs", "attrs": [("Ton", "100"), ("Frame", "H")]},
        {"name": "Industrial mixer", "short": "Ribbon blender", "desc": "Powder ribbon blender.", "price": 5600.0, "moq": "1 pcs", "attrs": [("Volume", "1000L"), ("Type", "Ribbon")]},
        {"name": "Pallet wrapper", "short": "Stretch wrap machine", "desc": "Automatic pallet stretch wrapper.", "price": 3900.0, "moq": "1 pcs", "attrs": [("Type", "Turntable"), ("Film", "LLDPE")]},
        {"name": "Metal shear", "short": "Hydraulic guillotine", "desc": "Hydraulic plate shear.", "price": 9800.0, "moq": "1 pcs", "attrs": [("Length", "2500"), ("Thick", "6mm")]},
        {"name": "Forklift 3T electric", "short": "Electric counterbalance", "desc": "3 ton electric forklift.", "price": 14500.0, "moq": "1 pcs", "attrs": [("Capacity", "3T"), ("Power", "Electric")]},
        {"name": "Dryer industrial", "short": "Hot air drying oven", "desc": "Industrial drying oven.", "price": 4200.0, "moq": "1 pcs", "attrs": [("Temp", "200C"), ("Type", "Hot air")]},
        {"name": "Filling machine liquid", "short": "Piston filler", "desc": "Multi-head liquid filling machine.", "price": 6500.0, "moq": "1 pcs", "attrs": [("Heads", "4"), ("Type", "Piston")]},
        {"name": "Labeling machine", "short": "Round bottle labeler", "desc": "Automatic round bottle labeling.", "price": 3800.0, "moq": "1 pcs", "attrs": [("Type", "Round"), ("Speed", "60")]},
        {"name": "Dust collector", "short": "Baghouse dust collector", "desc": "Industrial baghouse collector.", "price": 5200.0, "moq": "1 pcs", "attrs": [("Type", "Bag"), ("Fan", "Included")]},
        {"name": "Pump centrifugal SS", "short": "Stainless centrifugal pump", "desc": "SS centrifugal process pump.", "price": 680.0, "moq": "5 pcs", "attrs": [("Material", "SS316"), ("Type", "Centrifugal")]},
        {"name": "Gearbox helical", "short": "Helical gear reducer", "desc": "Helical gearbox for conveyors.", "price": 240.0, "moq": "20 pcs", "attrs": [("Ratio", "Custom"), ("Type", "Helical")]},
        {"name": "Industrial chiller", "short": "Air-cooled chiller", "desc": "Process air-cooled chiller.", "price": 7800.0, "moq": "1 pcs", "attrs": [("kW", "30"), ("Cool", "Air")]},
        {"name": "Roll forming line", "short": "Roof panel roll former", "desc": "Metal roof panel roll forming line.", "price": 35000.0, "moq": "1 set", "attrs": [("Profile", "Custom"), ("Speed", "15mpm")]},
    ],
}

# Fallback generic templates for other categories
GENERIC = [
    {"name": "OEM product model A", "short": "Factory OEM line A", "desc": "Standard OEM product for B2B buyers. Specs confirmable after sample.", "price": 12.0, "moq": "500 pcs", "attrs": [("OEM", "Yes"), ("Sample", "Available")]},
    {"name": "OEM product model B", "short": "Factory OEM line B", "desc": "Volume production item with custom branding options.", "price": 18.5, "moq": "300 pcs", "attrs": [("OEM", "Yes"), ("Custom", "Logo")]},
    {"name": "OEM product model C", "short": "Factory OEM line C", "desc": "Export-oriented SKU, carton packing.", "price": 9.9, "moq": "1000 pcs", "attrs": [("Pack", "Carton"), ("Export", "Yes")]},
    {"name": "Wholesale assortment pack", "short": "Mixed wholesale pack", "desc": "Assorted wholesale pack for distributors.", "price": 45.0, "moq": "50 packs", "attrs": [("Mix", "Yes"), ("Channel", "Wholesale")]},
    {"name": "Private label SKU", "short": "Private label ready", "desc": "Private label manufacturing with MOQ program.", "price": 22.0, "moq": "1000 pcs", "attrs": [("PL", "Yes"), ("Label", "Custom")]},
    {"name": "Bulk industrial grade", "short": "Industrial bulk grade", "desc": "Industrial-grade bulk product for factories.", "price": 65.0, "moq": "2 t", "attrs": [("Grade", "Industrial"), ("Bulk", "Yes")]},
    {"name": "Sample kit", "short": "Paid sample kit", "desc": "Paid sample kit for buyers before bulk order.", "price": 35.0, "moq": "1 kit", "attrs": [("Type", "Sample"), ("Refundable", "Order")]},
    {"name": "Spare / consumable pack", "short": "Consumables pack", "desc": "Consumables and spares for main product line.", "price": 8.0, "moq": "200 packs", "attrs": [("Type", "Consumable"), ("Pack", "Set")]},
    {"name": "Premium series", "short": "Premium export series", "desc": "Higher-spec export series with QC report.", "price": 39.0, "moq": "200 pcs", "attrs": [("QC", "Report"), ("Series", "Premium")]},
    {"name": "Economy series", "short": "Economy volume series", "desc": "Cost-optimized series for large tenders.", "price": 6.5, "moq": "2000 pcs", "attrs": [("Series", "Economy"), ("Tender", "Yes")]},
    {"name": "Accessories kit", "short": "Matching accessories", "desc": "Matching accessories for core SKUs.", "price": 4.2, "moq": "500 kits", "attrs": [("Type", "Accessory"), ("Match", "Core")]},
    {"name": "Custom colorway", "short": "Custom color program", "desc": "Custom color / finish program.", "price": 15.0, "moq": "800 pcs", "attrs": [("Color", "Custom"), ("Lead", "15d")]},
    {"name": "Carton display unit", "short": "Retail display carton", "desc": "Retail-ready display packaging unit.", "price": 11.0, "moq": "300 pcs", "attrs": [("Pack", "Display"), ("Retail", "Yes")]},
    {"name": "Heavy duty variant", "short": "Heavy-duty variant", "desc": "Reinforced heavy-duty variant.", "price": 28.0, "moq": "200 pcs", "attrs": [("Duty", "Heavy"), ("Reinforce", "Yes")]},
    {"name": "Compact travel size", "short": "Compact SKU", "desc": "Compact size for export logistics savings.", "price": 5.5, "moq": "1000 pcs", "attrs": [("Size", "Compact"), ("Logistics", "Light")]},
    {"name": "Pro toolkit edition", "short": "Pro edition kit", "desc": "Professional edition bundled kit.", "price": 55.0, "moq": "100 kits", "attrs": [("Edition", "Pro"), ("Bundle", "Yes")]},
    {"name": "Starter business pack", "short": "Starter pack for resellers", "desc": "Starter assortment for new distributors.", "price": 120.0, "moq": "20 packs", "attrs": [("Channel", "Distributor"), ("Pack", "Starter")]},
    {"name": "Certified export lot", "short": "Docs-ready export lot", "desc": "Lot prepared with commercial docs support.", "price": 80.0, "moq": "1 lot", "attrs": [("Docs", "Yes"), ("Export", "Yes")]},
    {"name": "Seasonal collection", "short": "Seasonal limited run", "desc": "Seasonal collection SKU.", "price": 16.0, "moq": "400 pcs", "attrs": [("Season", "Current"), ("Limited", "Yes")]},
    {"name": "Maintenance refill", "short": "Maintenance refill pack", "desc": "Refill/maintenance pack for installed base.", "price": 7.0, "moq": "300 packs", "attrs": [("Type", "Refill"), ("Service", "Yes")]},
]

def _lang_for(country: str) -> tuple[str, str]:
    c = country.upper()
    if c == "UZ":
        return "uz_UZ", "uz"
    if c in {"RU", "BY", "KZ", "KG", "TJ", "AM", "AZ", "MD"}:
        return "ru_RU", "ru"
    return "us_US", "en"


def _role_for(category: str) -> str:
    if category in {"services_b2b", "it_software"}:
        return "service"
    return "manufacturer"


def _currency_for(country: str) -> str:
    c = country.upper()
    if c == "UZ":
        return "USD"
    if c in {"RU", "BY"}:
        return "USD"
    if c == "KZ":
        return "USD"
    return "USD"


def _image_url(seed: str) -> str:
    h = hashlib.md5(seed.encode()).hexdigest()[:12]
    return f"https://picsum.photos/seed/{h}/800/800"


def _templates_for(category: str) -> list[dict]:
    return TEMPLATES.get(category) or GENERIC


def _product_payloads(company: str, category: str, n: int) -> list[dict]:
    base = _templates_for(category)
    out = []
    for i in range(n):
        t = base[i % len(base)]
        suffix = f" #{i // len(base) + 1}" if i >= len(base) else ""
        name = (t["name"] + suffix)[:100]
        short = t["short"][:120]
        desc = (
            f"{t['desc']} Supplier: {company}. "
            "Starter listing for partner onboarding — verify price/MOQ/specs after login."
        )[:500]
        attrs = [{"name": a[0][:40], "value": str(a[1])[:40]} for a in t["attrs"][:10]]
        # slight price jitter per company
        jitter = 1 + (abs(hash(company + name)) % 17) / 100.0
        price = round(float(t["price"]) * jitter, 2)
        if price <= 0:
            price = 1.0
        out.append(
            {
                "name": name,
                "short_description": short,
                "description": desc,
                "price": Decimal(str(price)),
                "moq": t["moq"],
                "attributes": attrs,
                "category": category if category in TEMPLATES or True else "other",
            }
        )
    return out


async def seed(*, dry_run: bool, products_only: bool, per_company: int) -> None:
    rows = [
        r
        for r in csv.DictReader(CREDS.open(encoding="utf-8-sig"))
        if (r.get("seed_ready") or "").strip() == "yes"
        and (r.get("email") or "").strip()
        and (r.get("password") or "").strip()
    ]
    print(f"Partners to process: {len(rows)}; per_company={per_company}; dry_run={dry_run}")
    if dry_run:
        for r in rows[:5]:
            print(f"  {r['id']} {r['email']} — {r['company_name'][:50]}")
        print(f"  ... total {len(rows)}")
        return

    factory = get_session_factory()
    created_users = 0
    created_products = 0
    skipped_users = 0
    status_map: dict[str, str] = {}

    async with factory() as db:
        for r in rows:
            email = r["email"].strip().lower()
            password = r["password"].strip()
            company = (r.get("company_name") or "").strip()
            country = (r.get("country") or "CN").strip().upper()[:2]
            category = (r.get("category_code") or "other").strip()
            website = (r.get("website") or "").strip() or None
            mid = (r.get("id") or "").strip()

            user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
            if user is None:
                if products_only:
                    print(f"missing user {email}, skip")
                    skipped_users += 1
                    continue
                app_lang, native = _lang_for(country)
                number = await assign_random_standard_number(db)
                user = User(
                    email=email,
                    password_hash=hash_password(password),
                    full_name=company[:100],
                    number=number,
                    birth_date=date(1985, 1, 1),
                    gender="other",
                    country=country,
                    app_language=app_lang,
                    native_language=native,
                    is_verified=True,
                    is_active=True,
                    verified_badge=False,
                )
                db.add(user)
                await db.flush()
                now = datetime.now(UTC)
                db.add(
                    Subscription(
                        user_id=user.id,
                        plan="business",
                        billing_cycle="yearly",
                        started_at=now,
                        expires_at=now + timedelta(days=365),
                        auto_renew=False,
                        is_active=True,
                        source="partner_seed",
                    )
                )
                db.add(
                    BusinessProfile(
                        user_id=user.id,
                        company_name=company[:200],
                        country=country,
                        business_role=_role_for(category),
                        website=(website[:255] if website else None),
                        description=(
                            f"{company} — AnyLang partner profile. Category: {category}. "
                            "Starter catalog seeded; please review and update."
                        )[:2000],
                        keywords=[category] if category else [],
                        payment_methods=["T/T"],
                        export_countries=[],
                        certificates=[],
                        incoterms=[],
                        description_i18n={},
                    )
                )
                created_users += 1
                status_map[mid] = "created"
                print(f"user {mid} {email}")
            else:
                status_map[mid] = "already_exists"
                skipped_users += 1

            # Products: skip if already have any for this seller
            existing_count = (
                await db.execute(
                    select(Product.id).where(Product.seller_id == user.id).limit(1)
                )
            ).first()
            if existing_count is not None:
                print(f"products exist for {email}, skip")
                continue

            currency = _currency_for(country)
            # Ensure category exists in PRODUCT_CATEGORIES — fallback other
            from app.services.products import PRODUCT_CATEGORIES

            cat = category if category in PRODUCT_CATEGORIES else "other"
            for p in _product_payloads(company, cat if cat != "other" else category, per_company):
                use_cat = cat if cat != "other" else (
                    category if category in PRODUCT_CATEGORIES else "other"
                )
                # if original category not in map, still use if present else other
                if category in PRODUCT_CATEGORIES:
                    use_cat = category
                else:
                    use_cat = "other"

                product = Product(
                    seller_id=user.id,
                    name=p["name"],
                    short_description=p["short_description"],
                    description=p["description"],
                    price=p["price"],
                    currency=currency,
                    category=use_cat,
                    status="published",
                    attributes=p["attributes"],
                    capabilities=["oem", "sample", "export"],
                    moq=p["moq"],
                    shipping_info="Sea / air freight — confirm with seller",
                    shipping_countries=[],
                )
                db.add(product)
                await db.flush()
                img = ProductImage(
                    product_id=product.id,
                    uploader_id=user.id,
                    url=_image_url(f"{mid}:{p['name']}"),
                    is_primary=True,
                    position=0,
                    attached_at=datetime.now(UTC),
                )
                db.add(img)
                created_products += 1

            print(f"products +{per_company} for {mid}")

        await db.commit()

    # Update credentials statuses (best-effort; /tmp may be read-only in container)
    try:
        all_rows = list(csv.DictReader(CREDS.open(encoding="utf-8-sig")))
        for r in all_rows:
            mid = (r.get("id") or "").strip()
            if mid in status_map:
                r["account_status"] = status_map[mid]
                if status_map[mid] == "created":
                    r["notes"] = "Biznes akkaunt + starter katalog yaratildi"
                elif status_map[mid] == "already_exists":
                    r["notes"] = "Email band — mahsulotlar tekshirildi/qo‘shildi"
        with CREDS.open("w", encoding="utf-8-sig", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(all_rows[0].keys()))
            w.writeheader()
            w.writerows(all_rows)
    except OSError as exc:
        print(f"WARN: credentials CSV status update skipped: {exc}")

    print(f"Done. users_created={created_users} users_skipped={skipped_users} products={created_products}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--products-only", action="store_true")
    p.add_argument("--per-company", type=int, default=20)
    args = p.parse_args()
    # Fix swimming attrs typo if any
    for t in TEMPLATES.get("clothing_accessories", []):
        fixed = []
        for a in t.get("attrs", []):
            if len(a) >= 2:
                fixed.append((a[0], a[1]))
        t["attrs"] = fixed
    asyncio.run(
        seed(
            dry_run=args.dry_run,
            products_only=args.products_only,
            per_company=args.per_company,
        )
    )


if __name__ == "__main__":
    main()
