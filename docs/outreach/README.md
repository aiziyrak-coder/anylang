# Ishlab chiqaruvchilar — outreach + partner akkauntlar

## Fayllar

| Fayl | Vazifa |
|------|--------|
| [`manufacturer_outreach.csv`](manufacturer_outreach.csv) | Bog‘lanish ro‘yxati |
| [`partner_credentials.csv`](partner_credentials.csv) | **Login / parol** (Excel’da oching) |

## Holat

- **Local Docker** va **production (`anylang.uz`)** ga seed qilindi
- **M015** — rad etilgan, akkaunt yo‘q
- **191** partner biznes akkaunt
- **~3820** published mahsulot
- Login: [`partner_credentials.csv`](partner_credentials.csv)

Prod qayta seed:
```bash
$env:ANYLANG_SSH_PASS='...'
python scripts/deploy_partner_seed_prod.py
```

## Muhim

- Alibaba **scrap qilinmagan**. Katalog — kategoriya bo‘yicha starter SKU (narx/MOQ/rasm partner tekshiradi).
- Placeholder (`[Pick Verified]`) qatorlar ochiq manufacturer shortlist bilan nomlangan — login qilib haqiqiy katalogga almashtirish kerak.
- Rasmlar vaqtincha `picsum.photos` — partner o‘z rasmini yuklaydi.

## Qayta seed (local)

```bash
# Placeholder nomlarni to‘ldirish (agar kerak)
python scripts/outreach/resolve_placeholders.py

# Credentials (agar yangidan)
python scripts/outreach/generate_partner_credentials.py

# DB
cd backend
python -m scripts.seed_partner_marketplace --dry-run
python -m scripts.seed_partner_marketplace --per-company 20
```

## Partnerga xabar

> AnyLang business account ready.  
> Login: [email]  
> Password: [password]  
> Please sign in, change password, replace product photos and confirm prices/MOQ.
