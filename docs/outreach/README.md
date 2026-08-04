# Ishlab chiqaruvchilar — outreach

## Fayllar

| Fayl | Vazifa |
|------|--------|
| [`manufacturer_outreach.csv`](manufacturer_outreach.csv) | Bog‘lanish ro‘yxati |
| `partner_credentials.csv` | Lokal login/parol (gitignore — GitHubga kirmaydi) |

## Holat

- Mock seed akkaunt/mahsulotlar **o‘chirilgan**.
- Haqiqiy katalog faqat partner o‘zi yuklaganda.

## Kerak bo‘lsa

```bash
python scripts/outreach/generate_manufacturer_list.py
python scripts/outreach/generate_partner_credentials.py
# DB tozalash (agar mock qayta paydo bo‘lsa):
cd backend && python -m scripts.purge_partner_seed --dry-run
```
