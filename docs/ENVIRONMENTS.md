# AnyLang — Prod vs Dev environments

Play Market chiqqandan keyin kod o‘zgarishlari **avval DEV**, keyin **PROD**.

| | **PROD** | **DEV** |
|---|---|---|
| URL | https://anylang.uz | https://dev.anylang.uz |
| Compose | `deploy/docker-compose.prod.yml` + `.env` | `deploy/docker-compose.dev.yml` + `.env.dev` |
| DB / volumes | alohida (`anylang`) | alohida (`anylang_dev`) — prod ma’lumotiga tegmaydi |
| Flutter | **Release / AAB** har doim PROD | **Debug / Profile** default DEV |
| To‘lov | Click live | mock (xavfsiz sinov) |

---

## Flutter qoidalari

| Buyruq | API |
|---|---|
| `flutter run` / debug | `https://dev.anylang.uz/` (+ ekranda **DEV** banner) |
| `flutter build appbundle --release` | **majburan** `https://anylang.uz/` |
| Debugda prod kerak bo‘lsa | `flutter run --dart-define=APP_ENV=prod` |
| Local backend | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/` |

Release buildga `APP_ENV=dev` yoki `API_BASE_URL=https://dev...` berib bo‘lmaydi — `assertProductionApiConfig()` to‘xtatadi.

---

## Server workflow

### 1) Bir marta: DEV stack yoqish

1. **DNS (majburiy):** `dev.anylang.uz` → VPS IP (`87.192.230.208`) A-record.
2. `python scripts/bootstrap_dev_stack.py` (SSH + compose + nginx + certbot).
3. Tekshiruv: `curl -fsS https://dev.anylang.uz/health`  
   Lokal (DNS bo‘lmasa): `curl -fsS http://127.0.0.1:8205/health` (serverda).

**DNS tayyor bo‘lguncha** Flutter debugni prodga ulash:
`flutter run --dart-define=APP_ENV=prod`

### 2) Har kunlik ish

```text
kod o‘zgardi
  → deploy DEV (scripts/deploy_to_dev.py)
  → flutter run  (DEV API)
  → tasdiqlandi
  → deploy PROD (mavjud prod deploy skriptlari)
  → flutter build appbundle --release  (faqat PROD)
```

### 3) DEV ga deploy

```bash
# Windows (repo ildizi)
set ANYLANG_SSH_PASS=...
python scripts/deploy_to_dev.py
```

Bu faqat `anylang-dev` konteynerlarini qayta build qiladi — **prod ishlashda qoladi**.

### 4) PROD ga promote

Devda hammasi OK bo‘lgach, odatiy prod deploy (`deploy_full_and_install.py`, `ship_full_release.py`, yoki kerakli patch skript).

---

## Portlar (bir VPS)

| Servis | PROD (localhost) | DEV (localhost) |
|---|---|---|
| API | 8105 | 8205 |
| Admin | 3105 | 3205 |
| Postgres | 15433 | 25433 |
| Redis | 16380 | 26380 |
| MinIO | 19002 | 29002 |

---

## Fayllar

- `deploy/docker-compose.dev.yml`
- `deploy/env.dev.template` → serverda `.env.dev`
- `deploy/nginx/dev.anylang.uz.conf`
- `Anylang/lib/data/core/buildNetwork/api_config.dart`
