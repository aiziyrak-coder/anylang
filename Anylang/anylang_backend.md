# AnyLang — Backend Texnik Topshiriq (TZ)

**Holati:** Asosiy modullar yozilgan — qarorlar yakunlangan; ops (kalitlar) va keyingi
bosqichlar (Remote Live, Admin, Push) 14-checklist da
**Qamrovi:** Auth · Profil/Hisob · Tariflar · Bozor · Xabarlar · Chat · Do'stlar · Tarmoq · Guruh chatlar · Jonli · Raqamlar · To'lov (Click+Paddle)

> Bu hujjat backend API'ni **modul-modul** tasvirlaydi. Har safar loyihaning yangi qismi
> ko'rib chiqilib, shu faylga **yangi bo'lim sifatida qo'shiladi** — mavjud bo'limlar
> keyinchalik keraksiz o'zgarmasligi uchun har bir qaror va sabab yoziladi.

> 📱 **Bu faylda faqat backend ishlari.** Flutter/mobil tomonidagi tasklar alohida hujjatda:
> [`anylang_mobile.md`](anylang_mobile.md). Bu yerda klient haqida gap ketsa — u faqat
> **kontrakt chegarasini** belgilash uchun (masalan "bu qiymatni backend yubormaydi, klient
> o'zi hisoblaydi"), task sifatida emas.

---

## 0. Loyiha haqida (backend jamoasi uchun kontekst)

**AnyLang** — turli tilda gaplashadigan odamlar bir-biri bilan erkin muloqot qilishi uchun
mobil ilova (Flutter, GetX). Asosiy funksiyalar (`main_bottom_nav.dart`dagi 5 ta tab):

| Tab | Vazifa |
|---|---|
| Xabarlar (Messages/Chat) | Foydalanuvchilar orasida matnli/ovozli chat, avtomatik tarjima bilan |
| Tarmoq (Network) | B2B kontakt/ishonch tarmog'i (UI nomi; 9-bo'lim state machine + **12-bo'lim**) |
| Bozor (Products) | Kichik biznes/hunarmandlar uchun mahsulot e'loni va katalogi |
| Jonli (Live) | Ikki kishi orasida **real vaqtda ovozli tarjima** (asosiy "wow" funksiya) |
| Profil | Foydalanuvchi profili, sozlamalar, obuna |

> ✅ **QAROR (Tarmoq vs Do'stlar):** pastki 2-tab UI nomi — **«Tarmoq»**. Bu 9-bo'limning
> oddiy qayta nomlanishi emas: **9 = friendship protokoli** (`/friends`, pending/accepted),
> **12 = B2B tarmoq qatlami** (trust, risk, viewers, filtrlar). Bitta UI ekran, ikki TZ
> bo'limi — batafsil **12.0**.

Qo'shimcha: **Subscription** (Basic — bepul / Premium / Business tariflari), **Biznes profil**
(sotuvchilar uchun sertifikat va ishlab chiqarish ma'lumotlari), **Guruh chatlar** (13-bo'lim).

Ushbu TZ hozircha faqat **kirish eshigi** — foydalanuvchi ilovaga birinchi marta kirganda
o'tadigan bosqichlarni (til tanlash, ro'yxatdan o'tish, email tasdiqlash, login, Google orqali
kirish, parolni tiklash, token yangilash) qamrab oladi. Qolgan modullar keyingi navbatda
alohida bo'lim sifatida qo'shiladi (4-bo'limga qarang).

### 0.1 Muhim eslatma — loyihadagi eski (legacy) kod bilan farq

Loyihani ko'rib chiqishda quyidagi nomuvofiqlik topildi va **hal qilindi** (foydalanuvchi bilan
kelishilgan qarorlar):

| Nima topildi | Qaror |
|---|---|
| `lib/data/network/auth_repository.dart` — telefon raqam + SMS OTP (`send-code`/`verify-code`) asosida yozilgan, avvalgi ("Navbat") loyihadan qolgan. | **Bekor qilinadi.** Yangi auth — faqat **email + parol** (+ Google). Bu fayl keyingi bosqichda shu TZ'ga mos qayta yoziladi. |
| `ProfileRepository.getRegions()` + sqflite `regions`/`districts` jadvallari — O'zbekiston viloyat/tuman tizimi. | **Bekor qilinadi.** Hozirgi Register/Business Info ekranlarida faqat **"davlat" (country)** maydoni bor — viloyat/tuman kerak emas. |
| `ProfileModel` (Flutter) — `region_id`, `district_id`, `phone` (auth uchun) kabi maydonlar. | Keyingi bosqichda ushbu TZ'dagi yangi `User` sxemasiga mos yangilanadi (hozircha kod o'zgartirilmaydi — faqat TZ yoziladi). |
| `TokenRefresher` / `ApiService` — JWT access+refresh, Bearer header, avtomatik yangilash — **to'liq to'g'ri va tayyor**, aniq bir kontraktni kutadi. | **O'zgarmaydi.** Backend aynan shu kontraktga mos bo'lishi SHART (3.9-bo'lim). |

---

## 1. Umumiy API konventsiyalari

### 1.0 Texnologiya steki — butun backend FastAPI'da

**Loyihaning barcha backend qismi — 3-bo'limdagi autentifikatsiyadan 10-bo'limdagi Jonli
rejimgacha, shu jumladan WebSocket — `FastAPI` (Python) da yoziladi.** Django yoki boshqa
freymvork ishlatilmaydi.

Quyidagi tavsiyalar butun loyihaga taalluqli (modulga xos izohlar o'z bo'limlarida beriladi,
masalan **10.10** — Jonli rejimning STT/TTS zanjiri uchun).

#### Tavsiya etiladigan stek

| Vazifa | Vosita | Qayerda kerak |
|---|---|---|
| Sxemalar / validatsiya | **Pydantic** | Hamma joyda — `/docs` (Swagger) avtomatik hosil bo'ladi, Flutter tarafi kontraktni shu yerdan tekshiradi |
| ORM | **SQLAlchemy 2.x (async)** yoki SQLModel | Hamma joyda |
| Migratsiyalar | **Alembic** | Hamma joyda |
| Asosiy baza | **PostgreSQL** | Hamma joyda |
| Kesh / hisoblagich / pub-sub | **Redis** | Presence (7.8), rate-limit (3.15, 9.0.1), tarjima keshi (8.1.1), WebSocket pub/sub |
| JWT | `PyJWT` yoki `python-jose` | 3-bo'lim |
| Parol hash | `passlib[bcrypt]` yoki `argon2-cffi` | 1.6, 3.13 |
| Tashqi HTTP chaqiruvlar | **`httpx.AsyncClient`** (timeout bilan) | Google token tekshirish, STT/TTS/tarjima |
| Fon vazifalari | `BackgroundTasks`, kattaroqlari uchun **ARQ**/Celery | Fayl tozalash, kechikkan tarjima (8.1.3) |
| Fayl saqlash | S3-mos obyekt saqlagich (yoki lokal + CDN) | Avatar, mahsulot rasmi, chat media, Jonli audio |

#### ⚠️ FastAPI'ning standart xulqi bu TZ bilan to'qnashadigan 3 ta joy

Bular **oldindan hal qilinmasa**, Flutter tarafi kutgan kontrakt buziladi:

**1. Xatolik formati.** FastAPI `HTTPException` va validatsiya xatolarini
`{"detail": ...}` ko'rinishida qaytaradi. Bu TZ esa **1.3-bo'limda**
`{"message": "...", "error_code": "..."}` formatini talab qiladi.
→ **Yechim:** `RequestValidationError` va `HTTPException` uchun **maxsus exception handler**
yozilsin, barcha xatolar bir xil formatda chiqsin:

```python
@app.exception_handler(RequestValidationError)
async def validation_handler(request, exc):
    return JSONResponse(
        status_code=400,
        content={"message": "...", "error_code": "VALIDATION_ERROR"},
    )
```

**2. Login form-data emas, JSON.** FastAPI hujjatlaridagi odatiy
`OAuth2PasswordRequestForm` **form-data** va `username`/`password` maydonlarini kutadi.
Bu TZ'da login (**3.6**) — **JSON** va **`email`**/`password`.
→ Standart OAuth2 form oqimi **ishlatilmaydi**; oddiy Pydantic model bilan JSON qabul qilinadi.
Bearer tokenni o'qish uchun oddiy `Depends` (yoki `HTTPBearer`) yetarli.

**3. WebSocket va bir nechta worker.** FastAPI'da WebSocket qo'llab-quvvatlanadi, lekin
uvicorn **bir nechta worker** bilan ishga tushirilsa, ulanishlar ro'yxati har bir jarayonda
alohida bo'ladi — 1-worker'dagi foydalanuvchiga 2-worker'dan event yuborib bo'lmaydi.
Natijada xabarlar tasodifiy "yetib bormaydi".
→ **Yechim:** WebSocket eventlari **Redis pub/sub** orqali tarqatilsin (7.9, 8.9, 9.5
eventlari va 7.8 presence shunga bog'liq).

#### Umumiy qoidalar

- Tashqi I/O bo'lgan har bir endpoint **`async def`** bo'lsin. Sinxron `def` FastAPI tomonidan
  thread pool'ga tashlanadi va yuk ostida tiqilib qoladi.
- Fayl yuklash — **`UploadFile`** (xotiraga to'liq o'qimasdan, stream bilan).
- Har bir tashqi chaqiruvga **timeout** qo'yilsin — bittasi osilib qolsa butun ishchi jarayon
  band bo'lmasin.
- `/docs` **ishlab chiqarish (production)** muhitida yopilsin yoki himoyalansin.

### 1.1 Base URL va versiyalash

- Barcha endpointlar prefiksi: **`api/v1/`** (mavjud kodda shunday: `api/v1/auth/...`, `api/v1/users/...`).
- Flutter tomonda `lib/data/core/buildNetwork/api_config.dart`dagi `kBaseUrl` placeholder
  (`'BASE_URL'`) — backend manzili tayyor bo'lgach shu bittagina joyda almashtiriladi.

### 1.2 So'rov / javob formati

- `Content-Type: application/json` (fayl yuklashda, masalan profil rasmi — `multipart/form-data`).
- Maydon nomlari **snake_case**.
- **Muvaffaqiyatli javob — o'rovsiz (envelope YO'Q).** Resurs to'g'ridan-to'g'ri qaytariladi:
  ```json
  { "id": 1, "full_name": "..." }
  ```
  ❌ Bunday emas: `{ "success": true, "data": {...} }`.
  Sabab: mavjud `ProfileRepository`/`TokenRefresher` kodi javobni to'g'ridan-to'g'ri
  parse qiladi (`response["access_token"]` kabi) — bu konventsiya o'zgarsa, allaqachon
  yozilgan Flutter kodi buziladi.

### 1.3 Xatolik formati

HTTP status kod + body:

```json
{
  "message": "Foydalanuvchiga ko'rsatiladigan xabar (backend tilida, language parametriga mos)",
  "error_code": "MACHINE_READABLE_CODE"
}
```

> **Eslatma backend jamoasi uchun:** hozirgi Flutter kodi (`network_client.dart`) hali bu
> body'ni o'qimaydi — faqat HTTP status/timeout turiga qarab umumiy xabar ko'rsatadi. Bu
> **backend tomon shu formatda javob qaytarishiga to'sqinlik qilmasin** — Flutter tarafi
> keyingi bosqichda shu `message`/`error_code`'ni o'qib, foydalanuvchiga aniq xabar
> ko'rsatadigan qilib yangilanadi. Hozirdanoq shu formatda qaytarilishi kerak.

| Status | Qachon ishlatiladi |
|---|---|
| `200` | Muvaffaqiyatli (GET/POST/PATCH) |
| `201` | Yangi resurs yaratildi (register) |
| `400` | Validatsiya xatosi (majburiy maydon yo'q, noto'g'ri format) |
| `401` | Autentifikatsiya xatosi (parol/token noto'g'ri yoki muddati o'tgan) |
| `403` | Ruxsat yo'q (akkaunt tasdiqlanmagan / bloklangan) |
| `404` | Resurs topilmadi |
| `409` | Konflikt (email allaqachon band) |
| `429` | Juda ko'p urinish (rate limit — OTP so'rovlari) |
| `500` | Server xatosi |

### 1.4 Autentifikatsiya (JWT)

- Himoyalangan har bir so'rovda: `Authorization: Bearer <access_token>`.
- **Access token muddati:** 30 daqiqa (mavjud `TokenRefresher` shu qiymatni taxmin qiladi).
- **Refresh token muddati:** 60 kun, **sliding** (har safar yangilanganda muddat qaytadan
  boshlanadi) — foydalanuvchi ilovani qayta ochganda qayta login qilmasligi uchun
  (pastda 3.1-bo'limdagi "ilova ishga tushishi" oqimiga qarang).
- Token refresh kontrakti **qat'iy** — 3.9-bo'limga qarang.

### 1.5 Til siyosati — IKKI XIL TIL (aralashtirmaslik kerak)

Loyihada **ikkita butunlay boshqa** til tushunchasi bor. Ularni bitta maydonda birlashtirish
mumkin emas — AnyLang'ning butun mohiyati shunga bog'liq.

| Maydon | Nima uchun | Qiymatlar |
|---|---|---|
| **`app_language`** | Ilova interfeysi tili + email/OTP xabarlar tili | Faqat **3 ta**: `uz_UZ`, `ru_RU`, `us_US` |
| **`native_language`** | Foydalanuvchining **ona tili** — xabarlar **shu tilga tarjima qilinadi**, profil/do'stlar ro'yxatida ko'rsatiladi | **Har qanday til** (ISO 639-1): `uz`, `ru`, `en`, `tr`, `es`, `de`, `fr`, `ja`, `zh`, ... |

#### Nega ikkita?

Til tanlash ekranida (S28) **7 ta** til bor, lekin ulardan faqat **3 tasida** interfeys tarjimasi
mavjud (`select_language_option.dart` da qolgan 4 tasining `localeCode` qiymati `null`).
Ekran matni buni aniq aytadi: *"Bu sizni ona tilingiz va ilova tili deb belgilanadi"*.

Ya'ni foydalanuvchi **"Deutsch"** ni tanlasa:
- `native_language = "de"` → unga kelgan xabarlar **nemis tiliga** tarjima qilinadi;
- `app_language` — o'zgarmaydi (nemischa interfeys yo'q), oldingi/standart qiymatda qoladi.

Buni tasdiqlaydigan joylar: `friends` ro'yxatida foydalanuvchilar **nemis, yapon, xitoy, chex,
ispan, italyan, fransuz** tillari bilan ko'rsatilgan; `jonli` ekrani esa "mening tilim" va
"suhbatdosh tili" uchun **7 talik `languageOptions`** ro'yxatini to'liq ishlatadi.

#### Qoidalar

- Register / Login / Google-login / Forgot-password so'rovlarida **ikkalasi ham** yuboriladi:
  `{ "app_language": "uz_UZ", "native_language": "uz" }`.
  `app_language` berilmasa → standart `uz_UZ`; `native_language` berilmasa →
  `app_language`dan olinadi (`uz_UZ → uz`).
- Email/OTP xabarlar **`app_language`** tilida yuboriladi (uchta tildan biri).
- Xabar tarjimasi (8.1) **`native_language`** ga qilinadi.
- Foydalanuvchi keyin Sozlamalardan ilova tilini o'zgartirsa — `app_language` yangilanadi;
  ona tilini o'zgartirsa — `native_language` yangilanadi (ikkalasi mustaqil).
- Ro'yxatga kengaytirish: yangi til qo'shilganda `native_language` uchun **backend kodni
  o'zgartirishi shart emas** (har qanday ISO 639-1 qabul qilinadi), `app_language` uchun esa
  tarjima fayllari qo'shilishi kerak.

> **Flutter tarafi (keyingi ish):** hozir `select_language_screen.dart` faqat `localeCode`ni
> (`uz_UZ` kabi) saqlaydi. Backend ulanganda tanlangan `LanguageOption`dan **ikkala** qiymat
> (`app_language` + `native_language`) yuboriladigan qilinadi; `LanguageOption`ga ISO 639-1
> kodi (`langCode`) maydoni qo'shiladi.

### 1.6 Xavfsizlik talablari

- Parollar **bcrypt** yoki **argon2** bilan hash qilinadi — hech qachon plain-text saqlanmaydi.
- Barcha so'rovlar faqat **HTTPS** orqali.
- OTP kodlar uchun rate-limit majburiy (3.15-bo'lim).
- JWT imzolash kaliti maxfiy environment o'zgaruvchisida saqlanadi, mobil kodda emas.
- `forgot-password` — email mavjud yoki yo'qligini oshkor qilmaydi (3.13-bo'limga qarang).

---

## 2. Modul: Til tanlash (Select Language)

**Ekran:** `select_language_screen.dart` → onboarding'dan oldingi birinchi ekran.

- **Bu ekran hech qanday backend API talab qilmaydi.** Tanlangan til to'liq client-local
  (Hive `user` box, `language` kaliti) saqlanadi — `main.dart`dagi `_getLanguage()`.
- Backend bilan yagona bog'liqlik: tanlangan qiymat keyinroq Auth so'rovlarida `language`
  maydoni sifatida yuboriladi (1.5-bo'limga qarang).
- Kelajakda backend orqali boshqariladigan dinamik tarjima/til ro'yxati kerak bo'lsa — alohida
  keyingi bosqichda ko'rib chiqiladi (hozircha talab yo'q).

---

## 3. Modul: Autentifikatsiya

Qamrab olingan ekranlar: `select_language` (yuqorida) → `onboarding` (backendsiz) →
`login_screen.dart`, `register_screen.dart`, `verify_screen.dart`.

### 3.1 Umumiy oqim

**A) Yangi foydalanuvchi:**

```
Register (full_name, email, password, ...) 
   → akkaunt yaratiladi (is_verified=false), 6 xonali kod emailga yuboriladi
   → Verify ekrani: foydalanuvchi kodni kiritadi
   → kod to'g'ri bo'lsa: akkaunt is_verified=true bo'ladi VA foydalanuvchi
     shu zahoti tizimga kiritiladi (access_token + refresh_token + user qaytadi)
   → Main ekran
```

**B) Mavjud foydalanuvchi (login):**

```
Login (email, password)
   → parol to'g'ri va is_verified=true bo'lsa: access_token + refresh_token + user qaytadi
   → Main ekran
```

**C) Google orqali kirish** — yangimi (avtomatik akkaunt yaratiladi, is_verified=true,
email Google tomonidan tasdiqlangan deb hisoblanadi, OTP kerak emas) yoki mavjudmi (to'g'ridan
login) — ikkalasida ham bir xil javob: `access_token + refresh_token + user`.

**D) Ilova qayta ochilganda (client-side, ma'lumot uchun):** Flutter tarafi Hive'da saqlangan
`refreshToken` mavjud va yaroqli bo'lsa, `api/v1/auth/refresh`ni chaqirib avtomatik login qiladi
va foydalanuvchini to'g'ridan-to'g'ri Main ekranga olib o'tadi (Login ekranini qayta
ko'rsatmaydi). Bu — Flutter tarafidagi kelajakdagi ish (hozircha `main.dart` doim Select
Language'dan boshlaydi); backend uchun ta'siri yo'q, faqat kontekst uchun keltirildi.

### 3.2 `User` obyekti

Barcha auth javoblarida (`register` bundan mustasno) qaytadigan asosiy sxema:

| Maydon | Tur | Izoh |
|---|---|---|
| `id` | int | |
| `full_name` | string | |
| `email` | string | |
| `number` | string (7 raqam) | **AnyLang raqami** — `"7831111"`, UI'da `783 11 11`. Register paytida **avtomatik** beriladi. Qidiruvda foydalanuvchi shu orqali topiladi. To'liq — **11-bo'lim** |
| `birth_date` | string (`YYYY-MM-DD`) \| null | |
| `gender` | `"male"` \| `"female"` \| null | |
| `country` | string (ISO 3166-1 alpha-2, masalan `"UZ"`) \| null | 3.14-bo'limga qarang |
| `avatar_url` | string \| null | |
| `is_business` | bool | Hisob "business" tarifidami — profil shakli shunga qarab o'zgaradi (4-bo'lim). `subscription.plan == "business"` bilan bir xil, klient qulayligi uchun alohida qaytariladi |
| `subscription` | object | Joriy obuna (plan, muddat, tugash sanasi) — to'liq sxema **5.3-bo'lim** |
| `verified_badge` | bool | Ishonchli sotuvchi belgisi (ko'k galochka). **`is_verified`dan farqli** — bu admin bergan trust-belgi (**4.14-bo'lim**) |
| `is_verified` | bool | Email tasdiqlanganmi (auth) |
| `is_active` | bool | Akkaunt bloklanmaganmi (admin tomonidan) |
| `profile_completed` | bool | `full_name`+`birth_date`+`gender`+`country` barchasi to'ldirilganmi (Google orqali ro'yxatdan o'tganlarda `false` bo'lishi mumkin) |
| `app_language` | `"uz_UZ"` \| `"ru_RU"` \| `"us_US"` | Interfeys va email tili (**1.5-bo'lim**) |
| `native_language` | ISO 639-1 (`"uz"`, `"de"`, `"ja"`, ...) | **Ona tili** — xabarlar shu tilga tarjima qilinadi (**1.5** va **8.1**) |
| `created_at` | string (ISO 8601) | Profildagi "a'zo bo'lgan sana" (member since) shundan olinadi |

> **Eslatma:** auth javoblaridagi (`login`/`verify-email`/`google`/`refresh`... — refresh bundan mustasno)
> `user` obyekti **4.1-bo'limdagi to'liq sxemaga teng** — shu jadvalda faqat auth uchun eng muhim
> maydonlar sanaldi. Nested `subscription` va (agar business bo'lsa) `business` obyektlari ham
> auth javobida to'liq keladi, shunda ilova birinchi kirishdayoq profilni to'liq chiza oladi.

### 3.3 `POST api/v1/auth/register`

**Request:**

```json
{
  "full_name": "Aliyev Vali",
  "email": "vali@example.com",
  "password": "Qwerty12",
  "birth_date": "1998-03-14",
  "gender": "male",
  "country": "UZ",
  "terms_accepted": true,
  "app_language": "uz_UZ",
  "native_language": "uz"
}
```

**Response `201`:**

```json
{
  "email": "vali@example.com",
  "message": "Tasdiqlash kodi emailingizga yuborildi",
  "resend_after_seconds": 60
}
```

> Token bu bosqichda **qaytarilmaydi** — akkaunt hali tasdiqlanmagan.

**Qoidalar:**
- **AnyLang raqami avtomatik beriladi** — akkaunt yaratilgan zahoti standart (bepul) guruhdan
  tasodifiy bo'sh raqam biriktiriladi (**11.6-bo'lim**). `number` hech qachon `null` bo'lmaydi.
- `email` — unique, formati tekshiriladi. Band bo'lsa → `409`, `error_code: "EMAIL_ALREADY_EXISTS"`.
- `password` — kamida 8 belgi (3.13-bo'lim).
- `terms_accepted` — `true` bo'lishi shart, aks holda `400 VALIDATION_ERROR`.
- Muvaffaqiyatli register'dan so'ng avtomatik 6 xonali OTP kod generatsiya qilinib emailga yuboriladi (3.15-bo'lim siyosatiga ko'ra).

### 3.4 `POST api/v1/auth/verify-email`

**Request:**

```json
{ "email": "vali@example.com", "code": "482913" }
```

**Response `200`:**

```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "user": { "...": "3.2-bo'limdagi User obyekti" }
}
```

**Xatoliklar:** `400 INVALID_CODE`, `400 CODE_EXPIRED`, `429 TOO_MANY_ATTEMPTS` (5 martadan
ko'p noto'g'ri urinishdan keyin — kod bekor qilinadi, foydalanuvchi qayta yuborishni so'rashi
kerak).

### 3.5 `POST api/v1/auth/resend-verification`

**Request:** `{ "email": "vali@example.com", "app_language": "uz_UZ" }`

**Response `200`:** `{ "message": "Kod qayta yuborildi", "resend_after_seconds": 60 }`

**Xatolik:** `429 RESEND_TOO_SOON` — agar cooldown (60 soniya) hali tugamagan bo'lsa.

### 3.6 `POST api/v1/auth/login`

**Request:**

```json
{ "email": "vali@example.com", "password": "Qwerty12", "app_language": "uz_UZ", "native_language": "uz" }
```

**Response `200`** (email+parol to'g'ri VA `is_verified=true`):

```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "user": { "...": "3.2-bo'limdagi User obyekti" }
}
```

**Response `403`** (email+parol to'g'ri, lekin `is_verified=false`):

```json
{
  "error_code": "ACCOUNT_NOT_VERIFIED",
  "message": "Email hali tasdiqlanmagan",
  "email": "vali@example.com",
  "resend_after_seconds": 60
}
```

> **Dizayn qarori:** bu holatda backend **avtomatik ravishda yangi OTP kod yuboradi** (xuddi
> `resend-verification` chaqirilgandek) — shunda foydalanuvchi Verify ekraniga tushganda kodni
> yana so'rashi shart bo'lmaydi. Flutter tarafi bu javobni ko'rib, foydalanuvchini
> `email`ni payload qilib Verify ekraniga yo'naltiradi.

**Response `401`** (email yoki parol xato): `{ "error_code": "INVALID_CREDENTIALS", "message": "Email yoki parol noto'g'ri" }`

**Response `403`** (akkaunt bloklangan, `is_active=false`): `{ "error_code": "ACCOUNT_DISABLED", "message": "..." }`

> **Eslatma:** login muvaffaqiyatli bo'lganda, agar `app_language` / `native_language`
> yuborilgan bo'lsa, backend foydalanuvchi profilidagi mos qiymatlarni yangilaydi
> (foydalanuvchi tilni boshqa qurilmada o'zgartirgan bo'lishi mumkin).

### 3.7 `POST api/v1/auth/google`

**Request:** `{ "id_token": "google-tomonidan-berilgan-id-token", "app_language": "uz_UZ", "native_language": "uz" }`

**Response `200`:** login bilan bir xil shakl — `{ access_token, refresh_token, user }`.

**Qoidalar:**
- Backend `id_token`ni Google'ning ochiq kaliti bilan tekshiradi (audience — mobil ilova
  Client ID'lariga mos bo'lishi kerak).
- Agar shu email bilan akkaunt mavjud bo'lmasa — yangi akkaunt avtomatik yaratiladi:
  `is_verified=true` (Google email'ni allaqachon tasdiqlagan, qo'shimcha OTP kerak emas),
  `full_name`/`avatar_url` Google profilidan olinadi, `birth_date`/`gender`/`country`
  **bo'sh qoladi** → shuning uchun bunday foydalanuvchida `profile_completed=false` bo'ladi
  (kelajakda "profilni to'ldirish" ekrani shu flag asosida ko'rsatiladi — hozircha UI yo'q).
- Agar shu email bilan akkaunt allaqachon **parol orqali** ro'yxatdan o'tgan bo'lsa — Google
  hisobi shu mavjud akkauntga bog'lanadi (email bo'yicha moslashtiriladi), yangi akkaunt
  yaratilmaydi.

> Eslatma: hozircha Flutter loyihasida `google_sign_in` paketi ulanmagan (`pubspec.yaml`da yo'q)
> — bu ekran hozircha faqat tugma, funksiyasiz. Backend endpoint tayyor bo'lgach, Flutter
> tarafda paket integratsiyasi alohida ish sifatida qo'shiladi.

### 3.8 `POST api/v1/auth/logout`

Header: `Authorization: Bearer <access_token>`
**Request:** `{ "refresh_token": "eyJ..." }`
**Response:** `200 { "message": "Chiqildi" }`

- Backend berilgan `refresh_token`ni serverda bekor qiladi (invalidate/blacklist) — shu orqali
  "hisobdan chiqish" boshqa qurilmalarga ta'sir qilmaydi, faqat shu sessiyani yopadi.
- Settings ekranida (`settings_screen.dart`) allaqachon `SettingsLogoutRequested` action
  mavjud (hozircha faqat lokal navigatsiya) — bu endpoint ulanganda shu action ichida
  chaqiriladi.

### 3.9 `POST api/v1/auth/refresh` — MAVJUD KLIENT KODIGA ANIQ MOS BO'LISHI SHART

Bu endpoint **allaqachon Flutter tomonda yozilgan** (`lib/data/core/buildNetwork/token_refresher.dart`)
va quyidagi aniq kontraktni kutadi — **o'zgarmaydi**:

**Request:**

```json
{ "refresh_token": "eyJ..." }
```

**Response `200`** (o'rovsiz, aynan shu 2 ta maydon):

```json
{ "access_token": "eyJ...", "refresh_token": "eyJ..." }
```

- `user` obyekti **qaytarilmaydi** (klient kodi buni o'qimaydi).
- Yangi `refresh_token` ham qaytishi shart — refresh token **sliding** (har ishlatilganda
  60 kunga uzayadi), shuning uchun eski refresh token endi yaroqsiz, yangisi saqlanadi.
- Eskirgan/yaroqsiz `refresh_token` yuborilsa → `401 INVALID_REFRESH_TOKEN` (Flutter tarafi bu
  holatda foydalanuvchini Login ekraniga qaytaradi — bu qism kelajakdagi client ishi).

### 3.10 `POST api/v1/auth/password/forgot`

**Request:** `{ "email": "vali@example.com", "app_language": "uz_UZ" }`

**Response `200`** (har doim, email mavjud bo'lsa ham, bo'lmasa ham — bir xil javob):

```json
{ "message": "Agar bu email ro'yxatdan o'tgan bo'lsa, tasdiqlash kodi yuborildi", "resend_after_seconds": 60 }
```

> **Xavfsizlik qoidasi:** javob **hech qachon** emailning mavjud yoki mavjud emasligini
> oshkor qilmaydi (aks holda uchinchi tomon qaysi emaillar ro'yxatdan o'tganini bilib olishi
> mumkin). Email haqiqatan mavjud bo'lsa — orqa fonda OTP kod yuboriladi; mavjud bo'lmasa —
> hech narsa yuborilmaydi, lekin javob bir xil.

### 3.11 `POST api/v1/auth/password/reset`

**Request:** `{ "email": "vali@example.com", "code": "482913", "new_password": "YangiParol1" }`

**Response `200`:** `{ "message": "Parol muvaffaqiyatli yangilandi" }`

**Qoidalar:**
- Token **qaytarilmaydi** — xavfsizlik uchun foydalanuvchi yangi parol bilan qaytadan Login
  qiladi (avtomatik login yo'q).
- Muvaffaqiyatli reset'dan keyin backend shu foydalanuvchining **barcha mavjud refresh
  token'larini bekor qiladi** (barcha qurilmalarda qayta login talab qilinadi — parol
  o'zgarganda eski sessiyalar xavfsizlik uchun yopiladi).
- Xatoliklar: `400 INVALID_CODE`, `400 CODE_EXPIRED` (3.15-bo'limdagi OTP siyosati bilan bir xil).

> **Eslatma:** hozirgi UI'da "Parolni unutdim" tugmasi bor (`login_action.dart` →
> `ForgotPassword`), lekin unga mos ekranlar (email kiritish / kod+yangi parol) hali
> loyihalanmagan. Backend shu 2 ta endpoint bilan tayyor turadi; Flutter ekranlari keyingi
> bosqichda shu kontraktga mos qurib chiqiladi. Shuningdek, Settings ekranidagi
> "parolni o'zgartirish" (`OpenChangePassword`, tizimga kirgan holda) — bu **boshqa**,
> alohida endpoint talab qiladigan funksiya, keyingi "Profil/Sozlamalar" TZ bosqichida
> ko'rib chiqiladi (bu yerga kiritilmagan).

### 3.12 Xatolik kodlari — umumiy jadval

| `error_code` | HTTP | Qayerda |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Har qanday endpoint — majburiy maydon yo'q/format xato |
| `EMAIL_ALREADY_EXISTS` | 409 | register |
| `INVALID_CREDENTIALS` | 401 | login |
| `ACCOUNT_NOT_VERIFIED` | 403 | login |
| `ACCOUNT_DISABLED` | 403 | login |
| `INVALID_CODE` | 400 | verify-email, password/reset |
| `CODE_EXPIRED` | 400 | verify-email, password/reset |
| `TOO_MANY_ATTEMPTS` | 429 | verify-email, password/reset |
| `RESEND_TOO_SOON` | 429 | resend-verification, password/forgot |
| `INVALID_REFRESH_TOKEN` | 401 | refresh |
| `INVALID_GOOGLE_TOKEN` | 401 | google |

### 3.13 Validatsiya qoidalari

| Maydon | Qoida |
|---|---|
| `email` | Standart email format, unique (register) |
| `password` | Kamida 8 belgi, kamida 1 harf + 1 raqam |
| `full_name` | Bo'sh bo'lmasin, 2–100 belgi |
| `birth_date` | `YYYY-MM-DD`, kelajakda bo'lmasin, foydalanuvchi kamida **13 yosh**da bo'lishi kerak *(bu yosh chegarasi — tavsiya, biznes tomonidan tasdiqlanishi kerak)* |
| `gender` | `"male"` \| `"female"` |
| `country` | ISO 3166-1 alpha-2 kod (3.14-bo'lim) |
| `terms_accepted` | `true` bo'lishi shart |

### 3.14 `country` — ISO kod xaritasi

Hozirgi Register ekranidagi davlat tanlash (`country_picker_bottom_sheet.dart`) statik ro'yxatdan
matn (masalan `"O‘zbekiston"`) qaytaradi. Backend **ISO alpha-2 kod** kutadi:

| UI'dagi nom | ISO kod |
|---|---|
| O'zbekiston | `UZ` |
| Qozog'iston | `KZ` |
| Rossiya | `RU` |
| Turkiya | `TR` |
| Qirg'iziston | `KG` |
| Tojikiston | `TJ` |
| AQSH | `US` |
| Germaniya | `DE` |

> **Eslatma (Flutter tomon uchun, keyingi bosqich):** hozir `country_picker_bottom_sheet.dart`
> faqat ko'rinadigan nomni qaytaradi, kodni emas — bu backend integratsiyasi paytida
> tuzatiladi (har bir davlat uchun nom+kod juftligi saqlanadi). Ro'yxat kelajakda
> kengaytirilishi mumkin — backend **istalgan valid ISO alpha-2 kodni** qabul qiladi, faqat
> shu 8 tasi bilan cheklanmaydi.

### 3.15 OTP siyosati

| Parametr | Qiymat |
|---|---|
| Kod uzunligi | 6 ta raqam |
| Amal qilish muddati | 5 daqiqa |
| Noto'g'ri urinishlar limiti | 5 marta (keyin kod bekor bo'ladi, qayta yuborish kerak) |
| Qayta yuborish (resend) cooldown | 60 soniya (mavjud `verify_content.dart` UI'dagi 59 soniyalik timer bilan mos) |
| Bitta email uchun soatlik limit | 5 ta so'rov/soat (spam himoyasi) |

---

## 4. Modul: Profil va Hisob turlari (Account types)

Qamrab olingan ekranlar: `profile` (S14 — o'z profili), `profile_edit` (S19 — shaxsiy profil
tahrirlash), `edit_business_info` (S17 — biznes profil tahrirlash), `user_profile` (boshqa
foydalanuvchi profili).

### 4.0 Asosiy tushuncha — hisob turi = obuna tarifi

Foydalanuvchining **profil ko'rinishi to'g'ridan-to'g'ri obuna tarifiga bog'liq** (rasmlarda ko'rilgan
3 xil shakl):

| Hisob turi | `subscription.plan` | `is_business` | Profil shakli (S14) |
|---|---|---|---|
| **Bepul (Free)** | `basic` | `false` | Shaxsiy profil: dumaloq avatar, obuna kartasi (tarif `basic`, muddatsiz), premium belgi **yo'q** |
| **Premium** | `premium` | `false` | Shaxsiy profil: dumaloq avatar, ism yonida **PREMIUM** belgisi, obuna kartasi (tarif + davr + tugash sanasi) |
| **Business** | `business` | `true` | **Biznes profil:** to'rtburchak avatar (logotip), BUSINESS belgisi, statistika (e'lonlar/ko'rishlar/reyting), sertifikatlar, zavod rasmlari, e'lonlar gridi, "+ Mahsulot" tugmasi |

**Qat'iy qoida:** alohida `role` maydoni **yo'q** — hisob "biznes"mi yoki yo'qmi faqat
`subscription.plan == "business"` orqali aniqlanadi. Backend qulaylik uchun buni `is_business`
(bool) bilan ham qaytaradi (klient qayta hisoblamasligi uchun). Foydalanuvchi "Business" tarifiga
o'tganda — hisob biznesga aylanadi va unga **bo'sh biznes profil** (`business` obyekti) biriktiriladi
(5.6-bo'limga qarang); tarifdan tushib qolsa — biznes profil ma'lumoti **o'chirilmaydi**, faqat
yashiriladi (qayta obuna bo'lsa tiklanadi).

### 4.1 To'liq `User` obyekti (GET /users/me javobi)

Bu — `api/v1/users/me` va barcha auth javoblaridagi `user` obyektining to'liq shakli:

```json
{
  "id": 42,
  "full_name": "Sardor Aliyev",
  "number": "7831111",
  "email": "sardor@example.com",
  "birth_date": "1998-03-14",
  "gender": "male",
  "country": "UZ",
  "avatar_url": "https://cdn.anylang.uz/avatars/42.jpg",
  "app_language": "uz_UZ",
  "native_language": "uz",

  "is_verified": true,
  "verified_badge": false,
  "is_active": true,
  "profile_completed": true,
  "created_at": "2024-03-02T09:12:00Z",

  "subscription": {
    "plan": "premium",
    "billing_cycle": "yearly",
    "started_at": "2025-09-12T10:00:00Z",
    "expires_at": "2026-09-12T10:00:00Z",
    "auto_renew": true,
    "is_active": true
  },

  "is_business": false,
  "business": null
}
```

**Business hisob uchun** `is_business: true`, `subscription.plan: "business"` va `business`
obyekti to'ldiriladi (4.5-bo'lim). Business hisobda profil ismi sifatida
`business.company_name` ko'rsatiladi (shaxsiy `full_name` emas).

**Maydonlar izohi:**

| Maydon | Tur | Izoh |
|---|---|---|
| `number` | string (7 raqam) | **AnyLang raqami** — foydalanuvchining yagona identifikatori. Bazada raqamlarsiz (`"7831111"`), UI'da `783 11 11` ko'rinishida. Register'da avtomatik beriladi, keyin almashtirish mumkin. To'liq — **11-bo'lim** |

> **MUHIM — `phone` va `username` maydonlari YO'Q.** Foydalanuvchining haqiqiy telefon raqami
> ilovaga umuman aloqador emas (kirish faqat email bilan), `@username` esa AnyLang raqami bilan
> almashtirildi. Ilovada raqam bilan bog'liq qayerda joy bo'lsa — hammasida shu `number`
> ishlatiladi (profil subtitle'i, biznes profildagi "aloqa" qatori, do'st qidirish, chat qidiruv).
| `avatar_url` | string \| null | `null` bo'lsa ilova ism harflaridan (initials) placeholder chizadi |
| `verified_badge` | bool | Ko'k galochka — 4.14-bo'lim |
| `subscription` | object | 5.3-bo'lim |
| `business` | object \| null | 4.5-bo'lim — faqat `is_business == true` bo'lganda to'ladi |

### 4.2 `GET api/v1/users/me`

Header: `Authorization: Bearer <access_token>`
**Response `200`:** 4.1-bo'limdagi to'liq `User` obyekti.

- Profil ekrani (`profile_screen.dart`) `initState`da shu so'rovni chaqiradi.
- Business hisobda `business.stats` (e'lonlar/ko'rishlar/reyting) shu javobda keladi — profildagi
  statistika kartalari uchun (4.5-bo'lim).

### 4.3 `PATCH api/v1/users/me` — shaxsiy profilni tahrirlash

Ekran: `profile_edit` (S19). Tahrirlanadigan maydonlar: ism, tug'ilgan sana, davlat, jins.

**Request** (faqat o'zgargan maydonlarni yuborish ham mumkin — barchasi ixtiyoriy):

```json
{
  "full_name": "Sardor Aliyev",
  "birth_date": "1998-03-14",
  "gender": "male",
  "country": "UZ",
  "app_language": "uz_UZ",
  "native_language": "uz"
}
```

**Response `200`:** yangilangan to'liq `User` obyekti.

**MUHIM — email tahrirlash:** S19 ekranida email maydoni ko'rinadi, lekin **`PATCH /users/me`
email'ni o'zgartirmaydi.** Email — sezgir maydon; o'zgartirish yangi email'ni OTP bilan qayta
tasdiqlashni talab qiladi. Bu alohida oqim (`POST /users/me/change-email` + tasdiqlash) va unga
mos UI hali yo'q — **keyingi bosqichga qoldirildi**. Hozircha backend bu endpointda `email`
maydonini **e'tiborsiz qoldiradi** (yoki `400 EMAIL_CHANGE_NOT_SUPPORTED` qaytaradi). Flutter
tarafi email maydonini shu bosqichda read-only qilib qo'yadi.

### 4.4 Avatar (profil rasmi)

Ekran: `profile_edit` → "Rasmni o'zgartirish". Rasm tanlangan zahoti yuklanadi (multipart).

**`POST api/v1/users/me/avatar`** — `multipart/form-data`, maydon nomi `file`.
**Response `200`:** `{ "avatar_url": "https://cdn.anylang.uz/avatars/42.jpg" }`

- Qabul qilinadigan format: JPEG/PNG/WebP, maksimal 5 MB. Server rasmni kvadrat qilib qisqartiradi
  (thumbnail).
- **`DELETE api/v1/users/me/avatar`** — rasmni olib tashlaydi (avatar `null` bo'ladi). `200`.

### 4.5 `business` obyekti (biznes profil ma'lumoti)

`User.business` — faqat business hisobda to'ladi. Ekranlar: `edit_business_info` (S17 — tahrirlash)
va `profile`/`user_profile` (ko'rsatish).

```json
{
  "company_name": "Anadolu Craft Co.",
  "logo_url": "https://cdn.anylang.uz/logos/42.jpg",
  "country": "TR",
  "business_role": "manufacturer",
  "website": "anadolucraft.com",
  "description": "Turkiyada 12 yildan beri qo'lda to'qilgan gazlama va charm mahsulotlar ishlab chiqaruvchi oilaviy korxona.",
  "founded_year": 2013,
  "certificates": ["ISO 9001", "CE Mark"],
  "factory_images": [
    { "id": 101, "url": "https://cdn.anylang.uz/factory/101.jpg" },
    { "id": 102, "url": "https://cdn.anylang.uz/factory/102.jpg" }
  ],
  "completeness": 92,
  "stats": {
    "listings_count": 8,
    "total_views": 3400,
    "rating": 4.9,
    "reviews_count": 37
  }
}
```

**Maydonlar:**

| Maydon | Tur | Izoh |
|---|---|---|
| `company_name` | string | Biznes profilda ism o'rniga ko'rsatiladi |
| `logo_url` | string \| null | Biznes avatari (to'rtburchak) |
| `country` | string (ISO alpha-2) | 3.14-bo'lim |
| `business_role` | enum | `manufacturer` \| `distributor` \| `retail` \| `service` — 4.5.1-bo'lim |
| `website` | string \| null | |
| `description` | string \| null | |
| `founded_year` | int \| null | Tashkil etilgan yil. Public profildagi "tajriba" (`experience`) shundan hisoblanadi (`hozirgi_yil − founded_year` → "12 yildan beri"). **UI gap** — tahrirlash ekranida hozircha maydon yo'q (`anylang_mobile.md`) |
| `certificates` | string[] | Sertifikat nomlari (masalan "ISO 9001"). Fayl emas — faqat matn |
| `factory_images` | `{id, url}[]` | Zavod/ishlab chiqarish rasmlari |
| `completeness` | int (0–100) | Profil to'ldirilganlik foizi — backend hisoblaydi (4.10-bo'lim) |
| `stats` | object | Statistika (4.13-bo'lim) — faqat o'qish uchun |

#### 4.5.1 `business_role` — enum va til xaritasi

Backend `enum` kod saqlaydi, UI'da tarjima ko'rsatiladi (`kBusinessRoles` ro'yxatiga mos):

| Kod | uz_UZ | ru_RU | us_US |
|---|---|---|---|
| `manufacturer` | Ishlab chiqaruvchi | Производитель | Manufacturer |
| `distributor` | Distributor | Дистрибьютор | Distributor |
| `retail` | Chakana savdo | Розничная торговля | Retail |
| `service` | Xizmat ko'rsatuvchi | Услуги | Service |

> **Eslatma:** hozir `edit_business_info_content.dart`dagi `kBusinessRoles` faqat o'zbekcha
> matnlarni saqlaydi va pickerdan matn qaytaradi. Backend integratsiyasida bu kod↔tarjima
> juftligiga o'tkaziladi (Flutter tarafidagi keyingi ish).

### 4.6 `GET api/v1/users/me/business`

Header: `Authorization: Bearer <access_token>`
**Response `200`:** 4.5-bo'limdagi `business` obyekti (tahrirlash ekranini to'ldirish uchun).
**Response `403 NOT_A_BUSINESS_ACCOUNT`:** hisob business tarifida bo'lmasa.

> Eslatma: `business` obyekti `/users/me` ichida ham keladi, shuning uchun bu alohida endpoint
> ixtiyoriy — tahrirlash ekrani to'g'ridan-to'g'ri `/users/me`dagi `business`ni ishlatishi ham
> mumkin. Lekin tahrirlashdan oldin eng yangi holatni olish uchun alohida GET tavsiya etiladi.

### 4.7 `PATCH api/v1/users/me/business` — biznes ma'lumotni tahrirlash

Ekran: `edit_business_info` (S17) → "Saqlash" tugmasi. Matn maydonlari + davlat + rol +
sertifikatlar **birgalikda** yuboriladi (logotip va zavod rasmlari alohida — 4.8/4.9).

**Request:**

```json
{
  "company_name": "Anadolu Craft Co.",
  "country": "TR",
  "business_role": "manufacturer",
  "website": "anadolucraft.com",
  "description": "Turkiyada 12 yildan beri ...",
  "founded_year": 2013,
  "certificates": ["ISO 9001", "CE Mark"]
}
```

**Response `200`:** yangilangan `business` obyekti.

- `certificates` — **to'liq massiv** sifatida yuboriladi (qo'shish/o'chirish klientda boshqariladi,
  saqlashda butun ro'yxat almashtiriladi). Alohida add/remove endpoint kerak emas.
- `403 NOT_A_BUSINESS_ACCOUNT` — business bo'lmagan hisob.

### 4.8 Biznes logotipi

**`POST api/v1/users/me/business/logo`** — `multipart/form-data`, maydon `file`.
**Response `200`:** `{ "logo_url": "https://cdn.anylang.uz/logos/42.jpg" }`
- Rasm tanlangan zahoti yuklanadi (avatar bilan bir xil qoidalar — 4.4).

### 4.9 Zavod rasmlari (factory images)

Ekran: S17 → "Yuklash" tugmasi. Har rasm tanlangan zahoti alohida yuklanadi.

- **`POST api/v1/users/me/business/factory-images`** — `multipart/form-data`, maydon `file`.
  **Response `201`:** `{ "id": 103, "url": "https://cdn.anylang.uz/factory/103.jpg" }`
- **`DELETE api/v1/users/me/business/factory-images/{id}`** — bitta rasmni o'chiradi. `200`.
  > Eslatma: hozirgi S17 UI'da faqat **qo'shish** bor (o'chirish tugmasi hali yo'q). DELETE
  > endpoint kelajakda o'chirish tugmasi qo'shilganda ishlatiladi — hozirdan tayyor turadi.
- Bitta biznes uchun maksimal rasm soni: **10 ta** (`400 FACTORY_IMAGES_LIMIT`).

### 4.10 `completeness` — hisoblash formulasi

Biznes profil "to'ldirilganlik" foizi (`user_profile`dagi progress bar, S14b). Backend hisoblaydi.
Har element teng ulush (jami 10 element × 10% = 100%):

| # | Element | To'ldirilgan hisoblanadi agar |
|---|---|---|
| 1 | Logotip | `logo_url != null` |
| 2 | Kompaniya nomi | `company_name` bo'sh emas |
| 3 | Davlat | `country != null` |
| 4 | Biznes roli | `business_role != null` |
| 5 | Veb-sayt | `website` bo'sh emas |
| 6 | Tavsif | `description` uzunligi ≥ 20 belgi |
| 7 | Tashkil etilgan yil | `founded_year != null` |
| 8 | Sertifikat | kamida 1 ta |
| 9 | Zavod rasmi | kamida 1 ta |
| 10 | E'lon (mahsulot) | kamida 1 ta e'lon joylangan |

### 4.11 `GET api/v1/users/{id}` — boshqa foydalanuvchi profili (public)

Ekran: `user_profile`. Chat/do'stlar/mahsulot orqali boshqa foydalanuvchi profiliga o'tilganda.

**Response `200`** (business foydalanuvchi misoli):

```json
{
  "id": 42,
  "is_business": true,
  "name": "Anadolu Craft Co.",
  "verified_badge": true,
  "country": "TR",
  "subtitle_role": "manufacturer",
  "number": "7831111",
  "avatar_url": "https://cdn.anylang.uz/logos/42.jpg",
  "business": {
    "business_role": "manufacturer",
    "founded_year": 2013,
    "website": "anadolucraft.com",
    "completeness": 92,
    "certificates": ["ISO 9001", "CE Mark"],
    "factory_images": [{ "id": 101, "url": "..." }],
    "stats": { "listings_count": 8, "total_views": 3400, "rating": 4.9 }
  }
}
```

**Shaxsiy (non-business) foydalanuvchi uchun:** `is_business: false`, `name` = `full_name`,
`subtitle_role` = `native_language` (public profil subtitle'da ona tili nomi ko'rsatiladi),
`business: null`.

**Maydonlar / qoidalar:**
- `name` — business bo'lsa `company_name`, aks holda `full_name`.
- `subtitle_role` — business bo'lsa `business_role` (kod), shaxsiy bo'lsa `native_language`
  (til kodi). UI subtitle ikkinchi qismida ko'rsatadi (`country · <bu>`), til nomini
  o'z lokalizatsiyasidan oladi.
- `number` — **har doim ochiq** qaytariladi: bu AnyLang raqami (haqiqiy telefon emas), aynan
  shu orqali odamlar bir-birini topadi. Dizayndagi biznes profilning "Telefon" qatorida ham
  shu raqam ko'rsatiladi (`+90 212 555 04 18` o'rniga `783 11 11`).
- Bloklangan foydalanuvchi profilini so'rasa → `403 USER_BLOCKED` (maxfiylik moduli, keyingi bosqich).
- `404 USER_NOT_FOUND` — mavjud emas yoki o'chirilgan hisob.
- Public profildagi e'lonlar (listings) gridi — **Bozor moduli** endpointidan olinadi
  (`GET /users/{id}/products?limit=...` — 6-bo'lim, Bozor bosqichida to'liq yoziladi). Bu yerda
  faqat `stats.listings_count` (jami son) qaytariladi.

### 4.12 Statistika (`stats`) — manba va hisoblash

Business profildagi 3 ta statistika kartasi (`profile_stat_card`, S14b):

| Ko'rsatkich | Manba |
|---|---|
| `listings_count` | Foydalanuvchi joylagan (aktiv) mahsulotlar soni — Bozor moduli hisoblaydi |
| `total_views` | Barcha mahsulot e'lonlari ko'rishlari yig'indisi. UI'da qisqartiradi ("3.4k") — backend **xom son** (`3400`) qaytaradi, formatlash Flutter tarafida |
| `rating` | O'rtacha reyting (0.0–5.0), 1 kasr. Sharhlar (reviews) moduliga bog'liq — u hali yo'q, shuning uchun **hozircha `null` yoki `0` qaytishi mumkin**; UI `0`/`null`ni "—" ko'rinishida ko'rsatadi. Sharh moduli qo'shilganda real hisoblanadi |

### 4.14 `verified_badge` vs `is_verified` — MUHIM farq

Loyihada ikki **butunlay boshqa** "tasdiqlangan" tushunchasi bor, ularni aralashtirmaslik kerak:

| Maydon | Ma'nosi | Kim beradi |
|---|---|---|
| `is_verified` | **Email tasdiqlangan** (OTP orqali) — 3-bo'lim, auth | Foydalanuvchi o'zi (kod kiritib) |
| `verified_badge` | **Ishonchli sotuvchi belgisi** — profil ismi yonidagi ko'k galochka (S14b, `ic_verified.svg`) | **Admin** (qo'lda tasdiqlaydi, hujjat/biznes tekshiruvidan so'ng) |

- `verified_badge` — foydalanuvchi o'zi o'zgartira olmaydi; faqat admin panelidan beriladi.
- Odatda faqat business hisoblarga beriladi, lekin sxema uni har qanday hisobda qo'llab-quvvatlaydi.
- Bu bosqichda **admin panel API'si yozilmaydi** — faqat `User.verified_badge` maydoni va uni
  qaytarish nazarda tutiladi (standart `false`).

### 4.15 Yutuqlar (Achievements)

Gamifikatsiya — profil/yutuqlar ekrani. Backend **unlock** holatini saqlaydi va hisoblaydi;
ikonka URL yoki kod klient lokal assetga bog'lashi mumkin.

#### 4.15.1 `GET api/v1/users/me/achievements`

**Response `200`:**

```json
{
  "items": [
    {
      "code": "TRANSLATIONS_100",
      "title": "100 ta tarjima",
      "icon": "translations_100",
      "unlocked": true,
      "unlocked_at": "2026-06-12T10:22:00Z",
      "progress": 100,
      "target": 100
    },
    {
      "code": "FIRST_LISTING",
      "title": "Birinchi e'lon",
      "icon": "first_listing",
      "unlocked": false,
      "unlocked_at": null,
      "progress": 0,
      "target": 1
    }
  ]
}
```

#### 4.15.2 `code` — enum va til xaritasi

| Kod | uz_UZ | ru_RU | us_US |
|---|---|---|---|
| `TRANSLATIONS_100` | 100 ta tarjima | 100 переводов | 100 translations |
| `LANGUAGES_10` | 10 til | 10 языков | 10 languages |
| `FIRST_LISTING` | Birinchi e'lon | Первое объявление | First listing |
| `RATING_5_STARS` | 5 yulduzli reyting | Рейтинг 5 звёзд | 5-star rating |
| `CONNECTIONS_50` | 50 ta aloqa | 50 связей | 50 connections |
| `VERIFIED_SELLER` | Tasdiqlangan sotuvchi | Проверенный продавец | Verified seller |

> Enum **kengaytiriladi** — yangi kod qo'shilganda shu jadval yangilanadi; noma'lum kodni
> klient "yutuq" umumiy matni bilan ko'rsatishi mumkin.

#### 4.15.3 Unlock triggerlari

| Kod | Qachon unlock | Kim tekshiradi |
|---|---|---|
| `TRANSLATIONS_100` | Foydalanuvchi jami ≥ 100 ta xabar tarjimasi (8.1) | Background job (ARQ) — kuniga yoki har N soat |
| `LANGUAGES_10` | Suhbatdoshlar / tarjima tillari bo'yicha ≥ 10 ta turli `native_language` | Background job |
| `FIRST_LISTING` | Birinchi `published` mahsulot yaratilganda | Sync (6.7) yoki job |
| `RATING_5_STARS` | Business `rating >= 4.95` va `reviews_count >= 5` | Job (sharh moduli bilan) |
| `CONNECTIONS_50` | Accepted friendship / tarmoq aloqalari ≥ 50 | Job (9 / 12) |
| `VERIFIED_SELLER` | `verified_badge == true` berilganda | Admin amali bilan sync |

**Qoidalar:**
- Bir marta unlock bo'lgach `unlocked_at` o'zgarmaydi (qayta hisoblanmaydi).
- `progress` / `target` — UI progress bari uchun; unlock bo'lsa `progress == target`.
- `title` — so'rov `Accept-Language` / `language` query bo'yicha lokalizatsiya (1.5).

**Xatoliklar:** `401 UNAUTHORIZED`.

### 4.16 AI Matching — «Sizning mahsulotingizni qidirayotganlar»

#### `GET api/v1/users/me/ai-matches`

Business foydalanuvchi uchun: o'z mahsulot kategoriyalari bilan boshqa foydalanuvchilarning
**qidiruv so'rovlari / ko'rishlari** orasidagi sodda moslik.

**v1 (soddalashtirilgan):** kim oxirgi 30 kunda shu `category` bo'yicha `GET /products`
qidirgan yoki sevimliga qo'shgan bo'lsa — ro'yxatga tushadi. To'liq ML embedding **emas**.

**Response `200`:**

```json
{
  "items": [
    {
      "user_id": 88,
      "company_name": "Nordic Imports",
      "country": "FI",
      "matched_category": "textiles",
      "match_percent": 78,
      "reason": "category_search"
    }
  ],
  "total": 1
}
```

**Qoidalar:**
- Faqat `subscription.plan == "business"` va aktiv obuna — aks holda `403 NOT_A_BUSINESS_ACCOUNT`
  yoki bo'sh `items` (mahsulot qarori: **403** tavsiya).
- `match_percent` — 0–100, v1 da kategoriya to'liq mosligi = 70–90 oralig'ida taxminiy ball.

### 4.17 AI Market Analytics — insight feed

#### `GET api/v1/users/me/market-insights`

**Response `200`:**

```json
{
  "items": [
    {
      "id": 501,
      "title": "Tekstil bozorida talab o'smoqda",
      "description": "Oxirgi 7 kunda «textiles» qidiruvlari +18%.",
      "category": "textiles",
      "created_at": "2026-07-20T08:00:00Z"
    }
  ]
}
```

> ✅ **QAROR (market-insights manbasi):** v1 — **faqat ilova ichidagi** signallar
> (ko'rishlar, e'lonlar, qidiruv/kategoriya fokus) + qoidalar agregatsiyasi; `OPENAI_API_KEY`
> bo'lsa matn boyitiladi (`generated_by: rules | openai | curated`). **Tashqi bozor API /
> hamkor feed** — keyingi bosqich (feature flag); v1 kontraktida tashqi manba shart emas.

**Xatoliklar:** `401 UNAUTHORIZED`.

### 4.18 Zavod videolari (factory videos)

4.9-dagi `factory_images` ga o'xshash, lekin **video**.

#### `POST api/v1/users/me/business/factory-videos`

`multipart/form-data`: `file` (video).

| Limit | Qiymat |
|---|---|
| Maksimal hajm | **100 MB** |
| Maksimal davomiylik | **120 soniya** (2 daqiqa) |
| Formatlar | `mp4`, `mov`, `webm` |
| Maksimal soni | 10 ta (rasmlar bilan alohida hisob) |

**Response `201`:**

```json
{
  "id": 901,
  "url": "https://cdn.anylang.uz/factory/42/v901.mp4",
  "thumbnail_url": "https://cdn.anylang.uz/factory/42/v901_thumb.jpg",
  "duration_seconds": 45,
  "file_size": 12400000
}
```

**Qoidalar:**
- Thumbnail — backend **avtomatik** generatsiya qiladi (ffmpeg yoki cloud transcoder).
- Faqat business hisob.
- `GET /users/me/business` va public profil (`4.11`) javobidagi `business.factory_videos`
  massiviga qo'shiladi.

**Xatoliklar:** `413 FILE_TOO_LARGE`, `400 VOICE_TOO_LONG` o'rniga `VIDEO_TOO_LONG`,
`UNSUPPORTED_FILE_TYPE`, `403 NOT_A_BUSINESS_ACCOUNT`.

#### `DELETE api/v1/users/me/business/factory-videos/{id}`

**Response `200`:** `{ "id": 901, "deleted": true }`

### 4.19 AnyLang raqami va QR kod

11-bo'limdagi `number` (7 xonali) — asosiy identifikator. UI'da «AnyLang raqami» + QR.

| Maydon | Izoh |
|---|---|
| `number` | Mavjud 7 xonali AnyLang raqami (3/11) — **yagona manba** |
| QR content | Deep link: `anylang://user/{id}` yoki `https://anylang.uz/u/{number}` |

**Klientda hisoblanadi (backend yubormaydi):**
- QR rasmning o'zi (bitmaps) — klient `qr` paketida `number` / deep link dan chizadi.
- Raqamni «783 11 11» ko'rinishida bo'shliq bilan formatlash.

> Agar alohida 10 xonali `anylang_number` kerak bo'lsa — bu **11-bo'lim bilan chalkashadi**.
> Hozirgi qaror: **yangi maydon qo'shilmaydi**, mavjud `number` ishlatiladi.

### 4.20 Kengaytirilgan analitika (vaqt seriyasi)

4.12-dagi oddiy `stats` ga qo'shimcha.

#### `GET api/v1/users/me/analytics?period=7d|30d`

**Response `200`:**

```json
{
  "period": "7d",
  "series": [
    {
      "date": "2026-07-19",
      "views": 120,
      "profile_visits": 14,
      "listing_clicks": 33
    },
    {
      "date": "2026-07-20",
      "views": 98,
      "profile_visits": 9,
      "listing_clicks": 21
    }
  ],
  "totals": {
    "views": 780,
    "profile_visits": 88,
    "listing_clicks": 210
  }
}
```

**Qoidalar:**
- Faqat o'z hisobi (`/me`). Boshqa foydalanuvchi analitikasiga `403`.
- `views` — e'lon ko'rishlari yig'indisi (6.14).
- `profile_visits` — 12.4 / 4.11 view tracking.
- `listing_clicks` — e'lon kartasiga bosish (klient event yuboradi yoki product detail ochilishi).
- Grafik chizish — **klient**; backend faqat xom kunlik sonlar.

**Xatoliklar:** `400 VALIDATION_ERROR` (noto'g'ri `period`), `403 NOT_A_BUSINESS_ACCOUNT`
(agar faqat businessga ochiq — tavsiya: business + premium).

### 4.21 Sertifikatlar sxemasi — BREAKING CHANGE

Hozirgi 4.5 / 4.7: `certificates: string[]` (faqat nom). UI skrinshotida raqamli kod
(`12908765`) alohida ko'rsatiladi — sxema o'zgaradi.

**Yangi shakl:**

```json
"certificates": [
  {
    "name": "ISO 9001",
    "number": "12908765",
    "issued_by": "TÜV",
    "issued_at": "2024-03-01",
    "file_url": "https://cdn.anylang.uz/certs/42/iso.pdf"
  }
]
```

| Maydon | Tip | Majburiy |
|---|---|---|
| `name` | string | ha |
| `number` | string \| null | yo'q |
| `issued_by` | string \| null | yo'q |
| `issued_at` | date (ISO) \| null | yo'q |
| `file_url` | string \| null | yo'q |

**Migratsiya:** eski `["ISO 9001"]` → `[{ "name": "ISO 9001", "number": null, ... }]`.
`PATCH /users/me/business` endi obyektlar massivini qabul qiladi.

> ⚠️ **BREAKING:** Flutter `business.certificates` tipini yangilash shart
> (`anylang_mobile.md`). Eski klient string kutsa — parse xato beradi.

### 4.22 Aniqlangan UI gap'lar (4-bo'lim qo'shimchalari)

| UI | Backend holati | Izoh |
|---|---|---|
| Yutuqlar ro'yxati / progress | 4.15 yozildi | Trigger job hali implementatsiya bo'lmasa UI mock ko'rsatishi mumkin |
| «N kompaniya qidirmoqda» banner | 4.16 | v1 content-based |
| Market insights kartalar | 4.17 | Ichki signal + ixtiyoriy LLM |
| Zavod video yuklash | 4.18 | Thumbnail serverda |
| QR kod | 4.19 | Rasm klientda |
| 7/30 kun grafik | 4.20 | Formatlash klientda |
| Sertifikat raqami | 4.21 | Breaking schema |

---

## 5. Modul: Tariflar va Obuna (Subscription)

Ekran: `subscription` (S16). Uch tarif — Basic (bepul) / Premium / Business.

### 5.1 Tarif turlari va xususiyatlari

| Tarif | Kod | Narx | Asosiy xususiyatlar (S16 kartalari) |
|---|---|---|---|
| Basic | `basic` | Bepul | Kuniga 20 ta tarjima; matn & ovozli chat; jonli rejim **yo'q** |
| Premium | `premium` | oylik/yillik | Cheksiz tarjima; jonli muloqot; reklamasiz; **kim profilni ko'rdi** (12.4) |
| Business | `business` | oylik/yillik | Premium'dagi barchasi; biznes profil & e'lonlar; sertifikat & ko'rish statistikasi |

- Narxlar **oylik va yillik** ko'rinishida (S16'da segmented toggle). Yillik ~20% arzon.
- Xususiyat matnlari va narxlar **backenddan** keladi (kelajakda o'zgartirish uchun) va `language`
  parametriga qarab lokalizatsiya qilinadi.

### 5.2 `GET api/v1/subscription/plans`

Query: `?billing_cycle=monthly|yearly` (ixtiyoriy — berilmasa ikkala narx ham qaytadi),
`?language=uz_UZ` (xususiyat matnlari tili uchun).

**Response `200`:**

```json
{
  "plans": [
    {
      "code": "basic",
      "title": "Basic",
      "is_free": true,
      "monthly_price": null,
      "yearly_price": null,
      "currency": "USD",
      "badge": null,
      "features": [
        { "text": "Kuniga 20 ta tarjima", "included": true },
        { "text": "Matn & ovozli chat", "included": true },
        { "text": "Jonli muloqot rejimi", "included": false }
      ]
    },
    {
      "code": "premium",
      "title": "Premium",
      "is_free": false,
      "monthly_price": "4.99",
      "yearly_price": "3.99",
      "currency": "USD",
      "badge": null,
      "features": [
        { "text": "Cheksiz tarjima", "included": true },
        { "text": "Jonli muloqot rejimi", "included": true },
        { "text": "Reklamasiz & ustuvor tezlik", "included": true }
      ]
    },
    {
      "code": "business",
      "title": "Business",
      "is_free": false,
      "monthly_price": "19.99",
      "yearly_price": "15.99",
      "currency": "USD",
      "badge": "SELLERS",
      "features": [
        { "text": "Premium'dagi barchasi", "included": true },
        { "text": "Biznes profil & e'lonlar", "included": true },
        { "text": "Sertifikat & ko'rish statistikasi", "included": true }
      ]
    }
  ]
}
```

- `yearly_price` — **oyiga** to'g'ri keladigan narx (UI "oyiga" deb ko'rsatadi, yillik to'lovda),
  `plan_card.dart`dagi `priceSuffix: 'subscription_per_month'` bilan mos.
- `badge` — kartadagi burchak yorlig'i (`null` bo'lsa yo'q). "JORIY TARIF" belgisi backenddan
  emas — u klientda `plan.code == user.subscription.plan` solishtiruvidan chiqadi.

### 5.3 `subscription` obyekti (User ichida)

```json
{
  "plan": "premium",
  "billing_cycle": "yearly",
  "started_at": "2025-09-12T10:00:00Z",
  "expires_at": "2026-09-12T10:00:00Z",
  "auto_renew": true,
  "is_active": true,
  "source": "purchase"
}
```

| Maydon | Tur | Izoh |
|---|---|---|
| `plan` | `basic`\|`premium`\|`business` | Joriy tarif |
| `billing_cycle` | `monthly`\|`yearly`\|`null` | `basic`da `null` |
| `started_at` | ISO 8601 \| null | Obuna boshlangan sana/vaqt. `basic`da `null` |
| `expires_at` | ISO 8601 \| null | Tugash sana/vaqt (profilda ko'rsatiladi). `basic` **muddatsiz** → `null` |
| `auto_renew` | bool | Avtomatik uzaytirish yoqilganmi |
| `is_active` | bool | Obuna hozir amaldami (`expires_at` o'tmaganmi) |
| `source` | `purchase` \| `number_bonus` | Obuna qayerdan kelgan. **`number_bonus`** — chiroyli raqam sotib olganda bonus sifatida berilgan (**11.4-bo'lim**); bunda `auto_renew: false` bo'ladi |

> Foydalanuvchi so'raganidek: obuna **User obyektida** keladi — aynan qaysi tarif, ulangan sana
> (`started_at`) va tugash sana+vaqti (`expires_at`).

### 5.4 `POST api/v1/subscription/subscribe`

Ekran: S16 → tarif kartasidagi "Tarifni tanlash" tugmasi.

**Request:** `{ "plan": "premium", "billing_cycle": "yearly" }`

**Response `200`:** yangilangan to'liq `User` obyekti (yangi `subscription` bilan).

**Qoidalar:**
- `basic`ga o'tish (downgrade) — bepul, darhol amalga oshadi.
- `premium`/`business`ga o'tish — **to'lov talab qiladi.** Klient avval
  `POST /subscription/checkout` (5.7) orqali to'lovni boshlaydi; webhook `paid`
  bo'lgach obuna faollashadi. To'g'ridan `subscribe` pullik planga → `402 PAYMENT_REQUIRED`.
- Joriy tarif bilan bir xil planga qayta so'rov → `400 ALREADY_ON_PLAN`.
- `business`ga o'tishda — 5.6-bo'lim (biznes profil yaratiladi).
- **Raqam tekshiruvi kerak emas:** har bir foydalanuvchida register paytidanoq raqam bor
  (11.6), shuning uchun "avval raqam oling" degan to'siq qo'yilmaydi.
- Chiroyli raqam sotib olish orqali ham tarif olish mumkin — **11.4-bo'lim** (bonus obuna).

### 5.5 `POST api/v1/subscription/cancel`

Header: `Authorization: Bearer <access_token>`
**Response `200`:** yangilangan `User` (obyekt `subscription.auto_renew: false`).

- **Bekor qilish darhol tarifni o'chirmaydi** — obuna `expires_at`gacha amalda qoladi, faqat
  avtomatik uzaytirish o'chadi. `expires_at` kelganda hisob avtomatik `basic`ga tushadi (5.8).

### 5.6 Business tarifga o'tish → biznes hisob

`subscribe` bilan `plan: "business"` bo'lganda:
- Hisob `is_business: true` bo'ladi.
- Agar biznes profil (`business`) ilgari mavjud bo'lmasa — **bo'sh** `business` obyekti
  yaratiladi (barcha maydonlar `null`/bo'sh, `completeness: 0`). Foydalanuvchi keyin S17'da
  to'ldiradi.
- Ilgari business bo'lib, keyin tushib qolgan bo'lsa — eski biznes ma'lumoti **saqlangan**
  bo'ladi va qayta tiklanadi (4.0-bo'lim qoidasi).

### 5.7 To'lov — Click (UZS) + Paddle MoR (USD)

Modul: `backend/app/payments/` (`click.py`, `paddle.py`, `service.py`, `router.py`).

#### Nima uchun ikki provayder

| Provayder | Kim uchun | Valyuta | Kartalar |
|---|---|---|---|
| **Click** | O'zbekiston (mahalliy) | UZS | Uzcard / Humo / mahalliy Visa-Mastercard |
| **Paddle** (Merchant of Record) | Xalqaro | USD | Chet ellik Visa / Mastercard |

O'zbekiston yuridik shaxsi Stripe/PayPal hisobiga to'g'ridan ulana olmaydi — xalqaro
kartalar uchun MoR (Paddle) orqali qabul qilinadi, daromad Payoneer/Wise/bankka o'tkaziladi.

`.env` (placeholder bo'lsa checkout URL stub qaytadi — TODO merchant credentials):

```
CLICK_MERCHANT_ID=
CLICK_SERVICE_ID=
CLICK_SECRET_KEY=
CLICK_MERCHANT_USER_ID=
PADDLE_API_KEY=
PADDLE_WEBHOOK_SECRET=
PADDLE_VENDOR_ID=
USD_UZS_RATE=12500
PAYMENT_PENDING_POLICY=cancel_and_recreate
PUBLIC_API_BASE_URL=https://anylang.uz
```

#### `payments` jadvali

| Maydon | Izoh |
|---|---|
| `provider` | `click` \| `paddle` (legacy: `mock` \| `stripe`) |
| `provider_transaction_id` | unique — webhook idempotentlik |
| `plan` / `billing_cycle` | `premium`\|`business` · `1`\|`12` (oy) |
| `amount` / `currency` | UZS yoki USD |
| `status` | `pending` \| `paid` \| `failed` \| `cancelled` \| `refunded` |
| `raw_payload` | JSONB — webhook audit / dispute |

**Qoida:** faqat `status=paid` bo'lganda `activate_subscription()` chaqiriladi (5.4/5.6).

#### `POST api/v1/subscription/checkout`

Yagona kirish nuqtasi (pullik tarif). Header: Bearer.

**Request:**

```json
{
  "plan": "premium",
  "billing_cycle": "yearly",
  "provider": "click"
}
```

`provider`: `click` \| `paddle`. Klient `country == "UZ"` bo'lsa Click ni default qilishi
mumkin, lekin foydalanuvchi ikkalasini ham tanlay oladi.

**Response `200`:**

```json
{
  "payment_id": 1042,
  "provider": "click",
  "checkout_url": "https://my.click.uz/services/pay?service_id=...&merchant_id=...&amount=...&transaction_param=1042",
  "amount": "159900.00",
  "currency": "UZS"
}
```

- Narx 5.2 plans (USD) dan; Click uchun `USD_UZS_RATE` orqali UZS ga konvertatsiya.
- `checkout_url` Flutter WebView da ochiladi.

> ✅ **QAROR (pending siyosat):** default **`cancel_and_recreate`** — foydalanuvchi
> yangi checkout so'rasa eski pending bekor qilinadi (ideal UX). Env orqali
> `return_existing` yoki `reject` (409) ham mumkin.

#### Click — Prepare / Complete

Hujjat: https://docs.click.uz (SHOP API).

1. Checkout URL: `transaction_param={payment_id}`, `return_url={PUBLIC_API_BASE_URL}/billing/success`
   (alias: `/payment/success`).
2. `POST /api/v1/payments/click/prepare` (JWT yo'q — faqat `sign_string`):
   - `md5(click_trans_id + service_id + SECRET + merchant_trans_id + amount + action + sign_time)`
   - amount mosligi; status `pending`
3. `POST /api/v1/payments/click/complete`:
   - formulaga `merchant_prepare_id` qo'shiladi
   - Prepare o'tgan bo'lishi shart; success → `paid` + `activate_subscription()`
   - Takroriy Complete → idempotent `error: 0`

#### Paddle — Billing API

Hujjat: https://developer.paddle.com

1. Checkout: `POST https://api.paddle.com/transactions` + `custom_data.payment_id`.
2. `POST /api/v1/payments/paddle/webhook` — `Paddle-Signature` HMAC-SHA256.
3. `transaction.completed` → `paid` + `activate_subscription(auto_renew=True)`.
4. `subscription.canceled` / `updated` → `User.subscription.auto_renew` sinxron.

#### `activate_subscription(user_id, plan, billing_cycle, auto_renew=…)`

Ikkala webhook shu umumiy funksiyani chaqiradi (`app/payments/service.py`).

> ✅ **QAROR (`expires_at`):**
> - **Bir xil plan** hali aktiv → qolgan muddat **saqlanadi**, yangi period **ustiga qo'shiladi** (erta yangilash).
> - **Plan o'zgarsa** yoki muddat o'tgan → `started_at=now`, `expires_at=now+period` (**qayta boshlanadi**).
> - Period: `30 * months` kun (`monthly`→30, `yearly`→360).
> - `auto_renew`: Click=`false` (one-shot); Paddle=`true` (MoR recurring).

> ✅ **QAROR (credentials):** Click/Paddle kalitlari va 4 ta Paddle `price_id` —
> **ops / .env** masalasi (kodda placeholder + stub URL). Product qarori emas;
> sandbox qiymatlari `.env.test` da, prod — deploy `.env`.

#### Xatolik kodlari

| `error_code` | HTTP | Qachon |
|---|---|---|
| `PAYMENT_ALREADY_PENDING` | 409 | Faol pending (`reject` siyosati) |
| `INVALID_PROVIDER` | 400 | provider na click na paddle |
| `PAYMENT_NOT_FOUND` | 404 | Webhook noma'lum payment_id |
| `AMOUNT_MISMATCH` | 400 | (Click ichki error -2; API xabar) |
| `SIGNATURE_INVALID` | 401 | Click/Paddle imzo noto'g'ri |
| `ALREADY_PROCESSED` | 200 | Idempotent takroriy webhook |
| `PAYMENT_REQUIRED` | 402 | `subscribe` pullik planga to'g'ridan |

#### Local test (ngrok)

Click/Paddle production serverlari `localhost` ga yetmaydi — tunnel kerak
(`backend/README.md`). Sandbox: `.env.test`. Pytest:
`tests/test_click_webhook_duplicate.py`, `tests/test_paddle_webhook_signature.py`.

### 5.8 Muddat tugashi va downgrade

- `expires_at` o'tgan va `auto_renew: false` → hisob **avtomatik `basic`ga** tushadi
  (`plan: "basic"`, `expires_at: null`, `is_business: false`).
- Business'dan tushganда — biznes profil va e'lonlar **o'chmaydi**, faqat yashiriladi
  (public profilda ko'rinmaydi, foydalanuvchi yangi e'lon qo'sha olmaydi). Qayta business
  bo'lsa — hammasi tiklanadi.
- `auto_renew: true` bo'lsa — `expires_at`da to'lov qayta olinadi (5.7 to'lov moduli).

---

## 6. Modul: Bozor (Products / Mahsulotlar)

Qamrab olingan ekranlar: `products` (S10 — Bozor ro'yxati), `product_info_bottom_sheet`
(S11 — mahsulot info), `add_product` (S18 — mahsulot qo'shish), `profile` (S14b —
"E'lonlarim" gridi), `user_profile` (S12 — biznes profilidagi e'lonlar).

### 6.0 Asosiy qoidalar

| Qoida | Tafsilot |
|---|---|
| **Kim e'lon qo'ya oladi** | Faqat **business** hisob (`subscription.plan == "business"`). Boshqa hisoblar → `403 NOT_A_BUSINESS_ACCOUNT` |
| **Kim ko'ra oladi** | Barcha ro'yxatdan o'tgan foydalanuvchilar (`published` statusdagi e'lonlar) |
| **E'lon limiti** | Business tarifda cheklanmagan (kelajakda konfiguratsiya orqali cheklash mumkin) |
| **Moderatsiya** | Bu bosqichda **yo'q** — e'lon darhol ko'rinadi. Admin qoidabuzar e'lonni `archived`ga o'tkazishi mumkin |

**Status (`status`) qiymatlari:**

| Status | Ma'nosi | Kim ko'radi |
|---|---|---|
| `draft` | Qoralama (S18 → "Qoralama" tugmasi) | Faqat egasi |
| `published` | E'lon qilingan (S18 → "E'lon qilish") | Hamma |
| `archived` | Arxivlangan / sotilgan / admin o'chirgan | Faqat egasi |

### 6.1 `Product` obyekti — ro'yxat (list item) shakli

S10 gridi va gorizontal ro'yxati, profil "E'lonlarim" gridi shu shaklni ishlatadi (yengil,
sotuvchi ma'lumotisiz):

```json
{
  "id": 501,
  "name": "Qo'lda to'qilgan sharf",
  "short_description": "100% jun · qo'lda to'qilgan · issiq",
  "price": "24.00",
  "currency": "USD",
  "primary_image_url": "https://cdn.anylang.uz/products/501/1.jpg",
  "views_count": 1200,
  "is_top": true,
  "is_favorited": false,
  "status": "published",
  "seller_id": 42,
  "created_at": "2026-05-02T09:12:00Z"
}
```

| Maydon | Izoh |
|---|---|
| `short_description` | S18'dagi "Qisqa tavsif". Grid kartasida **subtitle** sifatida ko'rsatiladi ("Qo'lda bo'yalgan") |
| `price` | **Decimal string** (`"24.00"`) — float emas (yaxlitlash xatosi bo'lmasligi uchun). Valyuta belgisi (`$`) klientda qo'shiladi |
| `primary_image_url` | Asosiy rasm ("Asosiy" belgisi qo'yilgan). Rasm yo'q bo'lsa `null` — klient placeholder ikon chizadi |
| `views_count` | **Xom son** (`1200`). UI "1.2k" ko'rinishida qisqartiradi — formatlash klientda (4.12 qarori bilan bir xil) |
| `is_top` | "TOP" belgisi ko'rsatiladimi (6.15-bo'lim) |
| `is_favorited` | Joriy foydalanuvchi sevimliga qo'shganmi (6.11-bo'lim) |

### 6.2 `ProductDetail` — to'liq shakl (S11 bottom sheet)

```json
{
  "id": 501,
  "name": "Qo'lda to'qilgan jun sharf",
  "short_description": "100% jun · qo'lda to'qilgan · issiq",
  "description": "Anadolu tog'larida qo'lda to'qilgan tabiiy jun sharf. Yumshoq, issiq va nafas oladi...",
  "price": "24.00",
  "currency": "USD",
  "category": "clothing_accessories",
  "status": "published",
  "views_count": 340,
  "is_top": false,
  "is_favorited": false,
  "created_at": "2026-05-02T09:12:00Z",

  "images": [
    { "id": 9001, "url": "https://cdn.anylang.uz/products/501/1.jpg", "is_primary": true,  "position": 0 },
    { "id": 9002, "url": "https://cdn.anylang.uz/products/501/2.jpg", "is_primary": false, "position": 1 },
    { "id": 9003, "url": "https://cdn.anylang.uz/products/501/3.jpg", "is_primary": false, "position": 2 }
  ],

  "attributes": [
    { "name": "Material", "value": "100% jun" },
    { "name": "Rang",     "value": "Bej" },
    { "name": "Uzunlik",  "value": "180 sm" }
  ],

  "seller": {
    "id": 42,
    "company_name": "Anadolu Craft Co.",
    "logo_url": "https://cdn.anylang.uz/logos/42.jpg",
    "verified_badge": true,
    "country": "TR",
    "business_role": "manufacturer"
  }
}
```

- `description` — S18'dagi "Batafsil tavsif" (maksimal 500 belgi).
- `attributes` — S11'dagi chip'lar (`Material: 100% jun`). UI `"{name}: {value}"` ko'rinishida
  chizadi. **UI gap** — S18'da hozircha kiritish maydoni yo'q (`anylang_mobile.md`).
- `seller` — S11 pastidagi biznes kartasi uchun. Bosilganda `seller.id` bilan S12 (public profil,
  **4.11-bo'lim**) ochiladi.

### 6.3 `GET api/v1/products` — ro'yxat, qidiruv, filtr

Query parametrlar (barchasi ixtiyoriy):

| Parametr | Tur | Izoh |
|---|---|---|
| `search` | string | Nom va qisqa tavsif bo'yicha qidiruv (S10 qidiruv maydoni) |
| `category` | enum | 6.12-bo'lim |
| `min_price` / `max_price` | decimal | Narx oralig'i |
| `currency` | enum | Filtrlash uchun |
| `seller_id` | int | Muayyan sotuvchi e'lonlari |
| `sort` | enum | `newest` (standart) \| `price_asc` \| `price_desc` \| `most_viewed` |
| `page` | int | 1'dan boshlanadi (standart 1) |
| `limit` | int | Standart 20, maksimal 50 |

**Response `200`:**

```json
{
  "items": [ { "...": "6.1-dagi Product" } ],
  "page": 1,
  "limit": 20,
  "total": 137,
  "has_more": true
}
```

**Qoidalar:**
- Faqat `status == "published"` e'lonlar qaytadi (egasining qoralamalari bu yerda ko'rinmaydi).
- Business tarifi tugagan sotuvchilar e'lonlari qaytmaydi (6.16-bo'lim).
- `search` — registrga sezgir emas (case-insensitive), qisman moslik (`LIKE %...%` yoki
  full-text). Uch tilli kontent bo'lgani uchun tarjima qilinmaydi — matn qanday yozilgan bo'lsa
  shunday qidiriladi.

> **Eslatma (Flutter tarafi):** hozir `products_content.dart` qidiruvni **klient tomonda**
> (yuklangan ro'yxat ustidan) filtrlaydi va butun ro'yxatni bir marta yuklaydi. Backend
> ulanganda qidiruv `search` parametriga, grid esa sahifalashga (`page`/`limit`, pastga
> scroll qilganda keyingi sahifa) o'tkaziladi.

### 6.4 `GET api/v1/products/top`

S10'dagi "Top mahsulotlar" gorizontal ro'yxati.

Query: `?limit=10` (standart 10).
**Response `200`:** `{ "items": [ { "...": "6.1-dagi Product" } ] }`

- Tanlash qoidasi — 6.15-bo'lim. Qaytgan har bir elementda `is_top: true`.

### 6.5 `GET api/v1/products/{id}` — mahsulot to'liq ma'lumoti

**Response `200`:** 6.2-bo'limdagi `ProductDetail`.

- **Ko'rishlar avtomatik +1 bo'ladi** — alohida endpoint kerak emas (6.14-bo'lim qoidalari).
- `404 PRODUCT_NOT_FOUND` — mavjud emas, yoki `draft`/`archived` bo'lib so'rovchi egasi emas.

### 6.6 `POST api/v1/products/images` — rasm yuklash

**MUHIM oqim:** S18'da mahsulot hali yaratilmagan bo'lsa ham rasm tanlanadi. Shuning uchun
rasmlar **avval mustaqil yuklanadi**, keyin mahsulot yaratishda ularning `id`lari beriladi.

- `multipart/form-data`, maydon `file`. Header: `Authorization: Bearer <token>`.
- **Response `201`:** `{ "id": 9001, "url": "https://cdn.anylang.uz/tmp/9001.jpg" }`
- Format: JPEG/PNG/WebP, maksimal 5 MB, bitta mahsulotga maksimal **10 ta** rasm.
- Yuklangan, lekin **24 soat ichida hech qaysi mahsulotga biriktirilmagan** rasm serverdan
  avtomatik o'chiriladi (bo'sh yotgan fayllar to'planmasligi uchun).
- **`DELETE api/v1/products/images/{id}`** — S18'dagi rasm ustidagi "X" tugmasi uchun. `200`.

### 6.7 `POST api/v1/products` — mahsulot yaratish (qoralama yoki e'lon)

S18 → "Qoralama" yoki "E'lon qilish" tugmasi. Farqi faqat `status` maydonida.

**Request:**

```json
{
  "name": "Qo'lda to'qilgan jun sharf",
  "short_description": "100% jun · qo'lda to'qilgan · issiq",
  "description": "Sof merino junidan an'anaviy usulda qo'lda to'qilgan sharf...",
  "price": "24.00",
  "currency": "USD",
  "category": "clothing_accessories",
  "image_ids": [9001, 9002, 9003],
  "primary_image_id": 9001,
  "attributes": [
    { "name": "Material", "value": "100% jun" },
    { "name": "Rang", "value": "Bej" }
  ],
  "status": "published"
}
```

**Response `201`:** 6.2-bo'limdagi `ProductDetail`.

**Qoidalar:**
- `status` — `"draft"` yoki `"published"` (boshqa qiymat → `400`).
- `image_ids` tartibi = ko'rsatilish tartibi (galereya). `primary_image_id` berilmasa —
  ro'yxatdagi **birinchi** rasm asosiy bo'ladi (S18 mantig'i bilan bir xil: birinchi qo'shilgan
  rasm avtomatik "Asosiy").
- Qoralamada validatsiya **yumshoq**: faqat `name` majburiy (foydalanuvchi yarim to'ldirib
  saqlashi mumkin). E'lon qilishda **to'liq** validatsiya (6.18-bo'lim).
- `403 NOT_A_BUSINESS_ACCOUNT` — business bo'lmagan hisob.

### 6.8 `PATCH api/v1/products/{id}` — tahrirlash

Profil → "E'lonlarim" → e'lon bosilganda ochiladigan tahrirlash ekrani uchun (hozircha
`OpenOwnListing` TODO holatida — `anylang_mobile.md`).

- Body — 6.7 bilan bir xil, barcha maydonlar **ixtiyoriy** (faqat o'zgarganini yuborish mumkin).
- `image_ids` berilsa — rasmlar ro'yxati **to'liq almashtiriladi** (sertifikatlar bilan bir xil
  yondashuv, 4.7-bo'lim).
- `status: "published"` qilib yuborilsa — qoralama e'lon qilinadi (to'liq validatsiya ishlaydi).
- **Response `200`:** yangilangan `ProductDetail`.
- `403 NOT_PRODUCT_OWNER` — boshqa birovning e'loni.

### 6.9 `DELETE api/v1/products/{id}`

- E'lon **butunlay o'chirilmaydi**, `status: "archived"` ga o'tadi (soft delete) — statistika
  (ko'rishlar) va chatdagi eski havolalar buzilmasligi uchun.
- **Response `200`:** `{ "message": "E'lon arxivlandi" }`
- `403 NOT_PRODUCT_OWNER`.

### 6.10 Sotuvchi e'lonlari

| Endpoint | Kim uchun | Izoh |
|---|---|---|
| `GET api/v1/users/me/products` | O'z profili (S14b "E'lonlarim") | **Barcha** statuslar (`draft` ham) qaytadi. `?status=draft\|published\|archived` bilan filtrlash mumkin |
| `GET api/v1/users/{id}/products` | Boshqa biznes profili (S12) | Faqat `published` |

- Ikkalasi ham 6.3 bilan bir xil sahifalangan javob (`items`/`page`/`total`/`has_more`) qaytaradi.
- Profil ekranidagi grid dastlab `?limit=4` bilan yuklanadi, "Barchasi" bosilganda to'liq ro'yxat.

### 6.11 Sevimlilar (favorites) — S11'dagi ♥ tugmasi

| Endpoint | Vazifa |
|---|---|
| `POST api/v1/products/{id}/favorite` | Sevimliga qo'shish → `200 { "is_favorited": true }` |
| `DELETE api/v1/products/{id}/favorite` | Olib tashlash → `200 { "is_favorited": false }` |
| `GET api/v1/users/me/favorites` | Sevimlilar ro'yxati (6.3 kabi sahifalangan) |

- `is_favorited` maydoni barcha mahsulot javoblarida joriy foydalanuvchiga nisbatan hisoblanadi.
- Takroriy `POST` xato emas (idempotent) — allaqachon sevimlida bo'lsa ham `200` qaytadi.

> **Eslatma:** hozir S11'dagi ♥ tugmasi faqat **lokal** holatni o'zgartiradi (`_fav`), so'rov
> yubormaydi, va ilovada "Sevimlilar" ekrani hali yo'q. Backend tayyor turadi — Flutter tarafi
> keyin ulaydi.

### 6.12 Kategoriyalar (`category`) — enum va tarjima

Backend `enum` kod saqlaydi, UI tarjimani ko'rsatadi (`kProductCategories` ro'yxatiga mos):

| Kod | uz_UZ | ru_RU | us_US |
|---|---|---|---|
| `clothing_accessories` | Kiyim & aksessuar | Одежда и аксессуары | Clothing & accessories |
| `pottery` | Kulolchilik | Керамика | Pottery |
| `woodwork` | Yog'och buyumlar | Изделия из дерева | Woodwork |
| `jewelry` | Taqinchoq | Украшения | Jewelry |
| `other` | Boshqa | Другое | Other |

- **`GET api/v1/products/categories`** — `?language=uz_UZ` bilan `[{ "code": "...", "title": "..." }]`
  qaytaradi (kategoriyalar kelajakda kengaytirilganda ilovani yangilash shart bo'lmasligi uchun).

### 6.13 Valyuta (`currency`)

Qo'llab-quvvatlanadigan qiymatlar (`kProductCurrencies` bilan bir xil): `USD`, `EUR`, `RUB`, `UZS`.

- Narx **konvertatsiya qilinmaydi** — sotuvchi qaysi valyutada kiritsa, shunday ko'rsatiladi.
- Klient valyuta belgisini o'zi qo'yadi (`USD → $`, `EUR → €`, `RUB → ₽`, `UZS → so'm`).

### 6.14 Ko'rishlar (`views_count`) hisoblash qoidasi

- `GET /products/{id}` chaqirilganda **avtomatik +1** (alohida endpoint yo'q).
- **Takroriy ko'rish hisoblanmaydi:** bitta foydalanuvchi bitta mahsulotni **24 soat ichida**
  necha marta ochsa ham — faqat **1 ta** ko'rish qo'shiladi (foydalanuvchi `id` + mahsulot `id`
  bo'yicha yozib boriladi).
- **Sotuvchining o'z e'lonini ochishi hisoblanmaydi.**
- Bu son biznes profilidagi `stats.total_views` yig'indisiga (**4.12-bo'lim**) ham kiradi.

### 6.15 "TOP" tanlash qoidasi

`is_top` — backend hisoblaydi, sotuvchi o'zi qo'ya olmaydi:

1. **Admin pinned** — admin qo'lda "top" qilib belgilagan e'lonlar birinchi navbatda (kelajakdagi
   admin panel; hozircha bo'sh).
2. Qolgan o'rinlar — **so'nggi 30 kundagi eng ko'p ko'rilgan** `published` e'lonlar.
3. Jami limit — 10 ta. Ro'yxat kuniga bir marta (yoki har soatda) qayta hisoblanadi (cache).
4. Bitta sotuvchidan TOP'da maksimal **2 ta** e'lon (bir biznes ro'yxatni egallab olmasligi uchun).

### 6.16 Obuna bilan bog'liqlik (business tarif tugaganda)

**5.8-bo'lim qoidasining davomi:**
- Sotuvchining business obunasi tugasa — uning e'lonlari **o'chirilmaydi**, lekin:
  - `GET /products` va `GET /products/top` ro'yxatlarida **ko'rinmaydi**;
  - `GET /users/{id}/products` (public) **bo'sh** qaytaradi;
  - to'g'ridan-to'g'ri `GET /products/{id}` → `404 PRODUCT_NOT_FOUND` (tashqi foydalanuvchi uchun);
  - egasi o'zi `GET /users/me/products`da hammasini ko'raveradi;
  - yangi e'lon qo'sha olmaydi → `403 NOT_A_BUSINESS_ACCOUNT`.
- Qayta obuna bo'lganda — barcha `published` e'lonlar **avtomatik qayta ko'rinadi**.

### 6.17 "Bog'lanish" tugmasi (S11) — Chat moduliga o'tish

- S11 pastidagi "Bog'lanish" tugmasi sotuvchi bilan **suhbat ochadi** (chat).
- Buning uchun mahsulot javobidagi `seller.id` yetarli — suhbat yaratish/ochish endpointi
  **Xabarlar moduli** (keyingi bosqich) da yoziladi.
- Lokalizatsiyada allaqachon `chat_product_label` ("MAHSULOT"), `chat_product_view` ("Ko'rish"),
  `chat_attach_product` kalitlari bor — ya'ni **mahsulotni chatga biriktirib yuborish** ham
  rejalashtirilgan. Chat xabarida mahsulot havolasi uchun `product_id` + qisqa ma'lumot
  (nom, narx, asosiy rasm) saqlanadi — batafsil Chat bosqichida.

### 6.18 Validatsiya va xatolik kodlari

**E'lon qilish (`status: "published"`) uchun majburiy:**

| Maydon | Qoida |
|---|---|
| `name` | 2–100 belgi |
| `short_description` | 1–120 belgi |
| `description` | maksimal **500** belgi (S18'dagi hisoblagich bilan bir xil), ixtiyoriy |
| `price` | 0 dan katta, maksimal 2 kasr |
| `currency` | 6.13-dagi enum |
| `category` | 6.12-dagi enum |
| `image_ids` | kamida **1 ta**, maksimal 10 ta |
| `attributes` | maksimal 10 ta; har `name` va `value` 1–40 belgi |

**Qoralama (`status: "draft"`) uchun:** faqat `name` majburiy, qolgani bo'sh bo'lishi mumkin.

| `error_code` | HTTP | Qachon |
|---|---|---|
| `NOT_A_BUSINESS_ACCOUNT` | 403 | Business bo'lmagan hisob e'lon qo'shmoqchi |
| `NOT_PRODUCT_OWNER` | 403 | Boshqa birovning e'lonini tahrirlash/o'chirish |
| `PRODUCT_NOT_FOUND` | 404 | Mavjud emas / arxivlangan / obunasi tugagan sotuvchiniki |
| `PRODUCT_IMAGES_LIMIT` | 400 | 10 tadan ko'p rasm |
| `PRODUCT_IMAGE_NOT_FOUND` | 400 | `image_ids`da mavjud bo'lmagan yoki boshqa foydalanuvchi yuklagan rasm `id` |
| `VALIDATION_ERROR` | 400 | Yuqoridagi qoidalar buzilsa |

### 6.19 Aniqlangan qo'shimchalar — «Siz uchun tavsiya»

#### `GET api/v1/products/recommended`

Shaxsiylashtirilgan mahsulotlar (Bozor asosiy ekrani / «Siz uchun» blok).

**v1 (content-based, ML emas):** foydalanuvchi oxirgi ko'rgan / sevimliga qo'shgan
mahsulotlarning `category` / `country` bo'yicha o'xshash e'lonlar. O'z e'lonlari chiqarib
tashlanadi.

**v2 (kelajak):** embedding / collaborative filtering — alohida bosqich.

**Query:** `page`, `limit` (standart 20).

**Response `200`:** 6.1-dagi `Product` list item shakli (`items`, `page`, `has_more`).

**Qoidalar:**
- Auth majburiy. Autentifikatsiyasiz — umumiy TOP (6.4) ga fallback yoki bo'sh — **tavsiya:
  auth majburiy, `401`**.
- Natija keshlanishi mumkin (Redis, 15–60 daqiqa).

### 6.20 Map View — geografik qidiruv

`business` obyektiga (4.5) qo'shimcha maydonlar:

| Maydon | Tip | Izoh |
|---|---|---|
| `latitude` | float \| null | WGS84 |
| `longitude` | float \| null | WGS84 |

`PATCH /users/me/business` orqali yangilanadi (ixtiyoriy).

#### `GET api/v1/products` — yangi query parametrlar (6.3 ga qo'shimcha)

| Query | Izoh |
|---|---|
| `near_lat` | Markaz kenglik |
| `near_lng` | Markaz uzunlik |
| `radius_km` | Radius (standart 50, max 500) |

**Qoidalar:**
- Uchala parametr birga beriladi; faqat bittasi → `400 VALIDATION_ERROR`.
- Masofa bo'yicha tartiblash ixtiyoriy (`sort=distance`).
- **Masofa matni ("1.2 km") backenddan kelmaydi** — klient `latitude`/`longitude` dan
  hisoblaydi (8.3.1 uslubi), yoki list itemga `distance_km` xom float qo'shilishi mumkin
  (tavsiya: **xom `distance_km`** qaytarish, format klientda).

### 6.21 Reklama bannerlari (carousel)

#### `GET api/v1/marketplace/banners`

Admin boshqaradigan kontent (public, auth ixtiyoriy).

**Response `200`:**

```json
{
  "items": [
    {
      "id": 1,
      "image_url": "https://cdn.anylang.uz/banners/1.jpg",
      "title": "Tekstil yarmarkasi",
      "link_type": "category",
      "link_value": "textiles",
      "position": 0
    }
  ]
}
```

| `link_type` | `link_value` |
|---|---|
| `category` | 6.12 enum kodi |
| `country` | ISO 3166-1 alpha-2 |
| `url` | https URL |
| `product` | product id (string) |

**Qoidalar:**
- Faqat aktiv (`is_active`) bannerlar; `position` o'sish tartibida.
- CRUD — **Admin panel** (14-bo'lim checklist).

### 6.22 «Durable» — mahsulot capability (sotuvchi badge emas)

> ✅ **QAROR:** «Durable» — **sotuvchi `verified_badge` emas**. Bu mahsulot
> `capabilities` massividagi kod: `"durable"` (chidamli / uzoq muddatli tovar).
> Boshqa capability lar qatori: `waterproof`, `eco_friendly`, `lightweight`, …
> (max 8 ta; `PRODUCT_CAPABILITIES` enum).

| Narsa | Qiymat |
|---|---|
| Qayerda | `Product.capabilities[]` — create/update/list/detail |
| UI | Chip / filter («Durable») — lokalizatsiya klientda (`product_cap_durable`) |
| Emas | Alohida `durable_badge` maydoni **yo'q**; `verified_badge` (admin) bilan aralashmasin |

### 6.23 Aniqlangan UI gap'lar (6-bo'lim qo'shimchalari)

| UI | Backend | Izoh |
|---|---|---|
| «Siz uchun tavsiya» | 6.19 | v1 sodda |
| Xarita / yaqin | 6.20 | lat/lng + radius |
| Banner carousel | 6.21 | Admin CRUD keyin |
| Durable chip | 6.22 | `capabilities: ["durable"]` |

---

## 7. Modul: Xabarlar — suhbatlar ro'yxati (S13)

Ekran: `messages` (S13 — "Xabarlar" tabi), `ui/items/conversation_item.dart`.

### 7.0 Qamrov

Bu bo'lim **faqat suhbatlar ro'yxati ekrani** va **chat qidiruv**ini qamraydi:
suhbatlar ro'yxati, oxirgi xabar ko'rinishi, o'qilmagan soni, onlayn holat, qidiruv.

**Bu bo'limga KIRMAYDI** (keyingi bosqich — "Chat" moduli): xabar yuborish, xabarlar tarixi,
avtomatik tarjima, ovozli xabar/fayl yuklash, reply, xabarni o'chirish/tahrirlash, typing
indikatori. Ular `chat` ekrani bosqichida yoziladi.

### 7.1 Suhbat qachon ro'yxatda paydo bo'ladi — ASOSIY QOIDA

> Foydalanuvchi so'rovi: *"kimdir bunga yozsa yoki kimgadir yozsa chat listda u suhbatdosh
> chiqib qoladi"*.

- Suhbat ro'yxatda **faqat birinchi xabar yuborilgandan keyin** paydo bo'ladi.
- Bo'sh suhbat (ochilgan, lekin hech kim yozmagan) `GET /chats`da **qaytmaydi** — Telegram bilan
  bir xil xulq. Shuning uchun "+" tugmasi yoki mahsulotdagi "Bog'lanish" bilan chat ochilib,
  foydalanuvchi hech narsa yozmasdan chiqib ketsa — ro'yxat iflos bo'lmaydi.
- Suhbat **ikkala tomonda ham** bir vaqtda paydo bo'ladi (kim yozgani muhim emas).
- Ro'yxat **oxirgi xabar vaqti bo'yicha kamayish tartibida** (eng yangisi tepada) saralanadi.

### 7.2 `Conversation` obyekti

```json
{
  "id": 77,
  "interlocutor": {
    "id": 15,
    "full_name": "Anna Müller",
    "avatar_url": "https://cdn.anylang.uz/avatars/15.jpg",
    "is_online": true,
    "last_seen_at": "2026-07-18T14:20:00Z",
    "is_business": false,
    "verified_badge": false
  },
  "last_message": {
    "id": 9812,
    "type": "text",
    "text": "Rahmat! Ertaga uchrashamizmi?",
    "is_outgoing": false,
    "status": "read",
    "created_at": "2026-07-18T14:32:00Z",
    "meta": null
  },
  "unread_count": 2,
  "updated_at": "2026-07-18T14:32:00Z"
}
```

| Maydon | Izoh |
|---|---|
| `id` | Suhbat (chat) identifikatori — chat ekraniga o'tishda ishlatiladi |
| `interlocutor` | **Suhbatdosh** (joriy foydalanuvchi emas). Ism, rasm, onlayn holat shundan olinadi |
| `interlocutor.avatar_url` | `null` bo'lsa — klient ism harfidan (initial) gradientli avatar chizadi (gradient klientda tanlanadi, backend yubormaydi) |
| `last_message` | Oxirgi xabar — 7.3-bo'lim |
| `unread_count` | Joriy foydalanuvchi o'qimagan xabarlar soni. `0` bo'lsa UI belgini ko'rsatmaydi |
| `updated_at` | Saralash uchun (oxirgi xabar vaqti) |

> **Guruh chatlar (13-bo'lim):** suhbat `type: "direct" | "group"` maydoni qo'shiladi.
> Guruhda `interlocutor` o'rniga `name` / `avatar_url` / `members_count` (batafsil 13).
> Eski klientlar uchun `type` yo'q bo'lsa — `direct` deb hisoblansin.

> **Eslatma:** `conversation_item.dart`dagi `highlighted` (lime fon) maydoni **backenddan
> kelmaydi** — u klientda `unread_count > 0` dan hisoblanadi (dizaynda o'qilmagan suhbat
> ajratib ko'rsatilgan).

### 7.3 `last_message` va ko'rinish (preview) qoidasi

```json
{
  "id": 9812,
  "type": "voice",
  "text": null,
  "is_outgoing": true,
  "status": "read",
  "created_at": "2026-07-18T12:05:00Z",
  "meta": { "duration_seconds": 12 }
}
```

**MUHIM qoida — preview matni backendda yasalmaydi.** Ilova 3 tilli (uz/ru/en), shuning uchun
backend **tayyor matn** (`"Ovozli xabar · 0:12"`) yubormaydi — u `type` + `meta` yuboradi,
klient esa o'z lokalizatsiya kalitlaridan (`chat_preview_voice`, `chat_preview_photo`, ...)
matnni yig'adi. Aks holda til almashtirilganda eski suhbatlar noto'g'ri tilda qolib ketadi.

| `type` | `meta` tarkibi | UI ko'rinishi (uz) |
|---|---|---|
| `text` | `null` | Xabar matnining o'zi (`text`) |
| `image` | `null` | 📷 Rasm |
| `voice` | `{ "duration_seconds": 12 }` | 🎤 Ovozli xabar · 0:12 |
| `file` | `{ "file_name": "Shartnoma.pdf", "file_ext": "PDF", "file_size": 253952 }` | 📎 Fayl (yoki fayl nomi) |
| `product` | `{ "product_id": 501, "product_name": "Qo'lda to'qilgan sharf" }` | Mahsulot nomi |
| `location` | `{ "label": "Do'kon manzili" }` | 📍 Joylashuv |
| `contact` | `{ "contact_name": "Ali Valiyev" }` | 👤 Kontakt |

- `type` qiymatlari `chat_message.dart`dagi `ChatMsgType` enum bilan **aynan bir xil**:
  `text`, `image`, `voice`, `product`, `location`, `file`, `contact`,
  `invoice`, `offer`, `catalog`, `business_card` (8.3).
- `is_outgoing` — oxirgi xabarni joriy foydalanuvchi yozganmi. `true` bo'lsa UI oldida ✓
  (yetkazilish) belgisi ko'rsatiladi.
- `status` — **faqat `is_outgoing: true` bo'lganda** ma'noli: `sent` | `delivered` | `read`
  (`ChatStatus` enumiga mos). Kiruvchi xabarda e'tiborsiz qoldiriladi.
- `text` — faqat `type == "text"` da to'ladi, qolganida `null`.
- **Tarjima:** AnyLang xabarlarni avtomatik tarjima qiladi. Ro'yxatdagi preview qaysi matnni
  (asl yoki tarjima) ko'rsatishi — **Chat moduli** bosqichida hal qilinadi; o'shanda
  `last_message`ga `translated_text` maydoni qo'shiladi. Hozircha `text` — asl matn.

### 7.4 `GET api/v1/chats` — suhbatlar ro'yxati

Header: `Authorization: Bearer <access_token>`

| Query | Izoh |
|---|---|
| `page` | 1'dan (standart 1) |
| `limit` | Standart 30, maksimal 50 |

**Response `200`:**

```json
{
  "items": [ { "...": "7.2-dagi Conversation" } ],
  "page": 1,
  "limit": 30,
  "total": 12,
  "has_more": false,
  "total_unread": 5
}
```

- `total_unread` — **barcha** suhbatlardagi o'qilmagan xabarlar yig'indisi (pastki
  navigatsiyadagi "Xabarlar" tabiga umumiy belgi qo'yish uchun; hozir UI'da yo'q, lekin
  qo'shilishi ehtimoli yuqori — bir so'rovda kelgani yaxshi).
- Bloklangan foydalanuvchi bilan suhbat ro'yxatda **ko'rinmaydi** (Maxfiylik moduli, keyingi bosqich).

### 7.5 `POST api/v1/chats` — suhbat ochish

Chaqiriladigan joylar: S13'dagi "+" tugmasi (`NewConversation`), mahsulotdagi "Bog'lanish"
(6.17-bo'lim), chat qidiruvdagi "yangi" foydalanuvchi bosilganda, do'stlar ro'yxatidan "Yozish".

**Request:** `{ "user_id": 15 }`
**Response `200`:** `{ "id": 77, "interlocutor": { "...": "7.2-dagi kabi" }, "is_new": true }`

- **Idempotent:** shu foydalanuvchi bilan suhbat allaqachon bo'lsa — mavjudi qaytadi
  (`is_new: false`), yangisi yaratilmaydi.
- Yaratilgan, lekin xabar yozilmagan suhbat `GET /chats`da **ko'rinmaydi** (7.1-qoida).
- `404 USER_NOT_FOUND`, `403 USER_BLOCKED` (biri ikkinchisini bloklagan bo'lsa),
  `400 CANNOT_CHAT_WITH_SELF`.

### 7.6 `POST api/v1/chats/{id}/read` — o'qilgan deb belgilash

**Request:** `{ "message_ids": [9805, 9807, 9812] }`
**Response `200`:** `{ "read_message_ids": [9805, 9807, 9812], "unread_count": 4, "read_at": "2026-07-18T14:33:40Z" }`

- Xabar **ekranda haqiqatan ko'ringanda** o'qilgan bo'ladi — chat ochilishi bilan hammasi emas.
- ID'lar **to'plamlab (batch)** yuboriladi, har xabar uchun alohida so'rov emas.
- To'liq qoidalar (klient va backend tomoni) — **8.7-bo'lim**.
- Suhbatdoshga real-time `message_read` eventi yuboriladi (8.9) — u o'z tomonida ✓✓ ko'radi.

### 7.7 `GET api/v1/chats/search` — CHAT SEARCH (Telegram uslubidagi qo'sh ro'yxat)

> Foydalanuvchi so'rovi: *"qidirganda 2 xil list keladi responseda — chatlar ichida
> yozishganlari ichidan qidiradi, umumiy yozishmagan odamlari ichidan qidiradi"*.

#### 7.7.0 ⚠️ Qidiruv turi so'rovning o'ziga qarab aniqlanadi

**Yangi logika (11-bo'limdagi raqamlar tizimi bilan bog'liq):**

| Nima yozilgan | Nima qidiriladi | Javob |
|---|---|---|
| **Matn** (ism) — `"anna"` | **Faqat o'z suhbatlari** ichidan: suhbatdosh ismi + yozishmalar matni | `chats[]` to'ladi, **`users[]` bo'sh** |
| **Raqam** — `"783"`, `"7831111"` | Ham suhbatlari, ham **butun baza** | `chats[]` + `users[]` — ikkalasi ham |

**Sabab:** yangi odamni ismi bilan topib bo'lmaydi — faqat **AnyLang raqami** orqali topiladi
(11-bo'lim). Bu ham maxfiylik (istalgan odamni ismidan qidirib topib bo'lmaydi), ham
mahsulot qarori (raqam — asosiy identifikator).

**Backend qanday ajratadi:** `query`dan bo'sh joy va `-` belgilari olib tashlanadi; agar
qolgani **faqat raqamlardan** iborat bo'lsa → **raqam qidiruvi**, aks holda → **ism qidiruvi**.
Klient hech narsa yubormaydi, tur avtomatik aniqlanadi.

```
"anna"        → ism qidiruvi     → users[] bo'sh
"783 11 11"   → raqam qidiruvi   → users[] to'ladi
"7831111"     → raqam qidiruvi   → users[] to'ladi
"783"         → raqam qidiruvi   → users[] to'ladi (qisman moslik, 7.7.1)
```

Javobda `search_type` maydoni qaytariladi (`"name"` yoki `"number"`) — UI shunga qarab
"raqam bilan qidiring" degan maslahat ko'rsatishi mumkin.

**Query parametrlar:**

| Parametr | Tur | Izoh |
|---|---|---|
| `query` | string | **Majburiy**, kamida 1 belgi |
| `limit_chats` | int | Standart 20 |
| `limit_users` | int | Standart 20 |

**Response `200`:**

```json
{
  "query": "an",
  "search_type": "name",
  "chats": [
    {
      "id": 77,
      "interlocutor": {
        "id": 15,
        "full_name": "Anna Müller",
        "avatar_url": "https://cdn.anylang.uz/avatars/15.jpg",
        "is_online": true,
        "last_seen_at": "2026-07-18T14:20:00Z",
        "is_business": false,
        "verified_badge": false
      },
      "last_message": { "...": "7.3-dagi last_message" },
      "unread_count": 2,
      "updated_at": "2026-07-18T14:32:00Z",
      "match_type": "name",
      "matched_message": null
    },
    {
      "id": 91,
      "interlocutor": { "id": 22, "full_name": "Marco Rossi", "...": "..." },
      "last_message": { "...": "..." },
      "unread_count": 0,
      "updated_at": "2026-07-12T10:02:00Z",
      "match_type": "message",
      "matched_message": {
        "id": 8800,
        "text": "Ertaga anjumanga boramizmi?",
        "created_at": "2026-07-11T18:40:00Z",
        "is_outgoing": true
      }
    }
  ],
  "users": [
    {
      "id": 31,
      "full_name": "Andrea Costa",
      "number": "4862793",
      "avatar_url": null,
      "is_online": false,
      "last_seen_at": "2026-07-18T09:10:00Z",
      "country": "IT",
      "native_language": "it",
      "is_business": false,
      "verified_badge": false
    }
  ]
}
```

#### 7.7.1 `chats[]` — mavjud yozishmalar ichidan

Ikkala qidiruv turida ham to'ladi (foydalanuvchi allaqachon suhbatlashgan odamlar):

- **Ism qidiruvida** ikki joydan boradi:
  1. **Suhbatdosh ismi** bo'yicha (`full_name`) → `match_type: "name"`
  2. **Xabarlar matni** ichidan (`type == "text"`) → `match_type: "message"`,
     `matched_message` to'ladi (chat ichida o'sha xabarga sakrash uchun `id` bilan)
- **Raqam qidiruvida** — suhbatdoshning `number`i bo'yicha → `match_type: "number"`.
- Bitta suhbatda bir nechta xabar mos kelsa — **eng oxirgisi** qaytariladi (bitta qator).
  Ism ham, xabar ham mos kelsa — `match_type: "name"` ustun (Telegram xulqi).
- Saralash: avval `name`/`number` moslar (oxirgi faollik bo'yicha), keyin `message` moslar
  (topilgan xabar vaqti bo'yicha yangidan eskiga).

#### 7.7.2 `users[]` — hali yozishmagan odamlar

- **Faqat raqam qidiruvida to'ladi.** Ism qidiruvida **doim bo'sh massiv** qaytadi
  (7.7.0-qoida).
- `number` bo'yicha **qisman moslik** (prefiks): `"783"` → `783 11 11`, `783 45 67` ...
  Bu foydalanuvchi raqamni to'liq eslay olmasa ham topishi uchun.
  > Kamida **3 ta raqam** kiritilishi shart — aks holda `users[]` bo'sh qaytadi
  > (`"7"` yozib butun bazani ko'rib chiqishning oldini oladi).
- **Muhim:** bu ro'yxatga suhbati bor odamlar **kirmaydi** (ular `chats[]` da chiqadi —
  dublikat bo'lmaydi).
- O'zini, bloklaganlarni va bloklaganlarini o'z ichiga olmaydi.
- `is_active: false` hisoblar chiqmaydi.

#### 7.7.3 Umumiy qoidalar

- Ism qidiruvi registrga sezgir emas (case-insensitive), qisman moslik.
- Raqam qidiruvida bo'sh joy/`-` e'tiborsiz: `"783 11 11"` = `"7831111"`.
- Ikkala ro'yxat ham bo'sh bo'lsa — `200` va bo'sh massivlar (xato emas).
- Raqam qidiruviga **rate limit**: daqiqada 20 ta so'rov (ketma-ket raqam sinab bazani
  yig'ib olishning oldini oladi).
- `400 VALIDATION_ERROR` — `query` bo'sh bo'lsa.

> **Eslatma (Flutter tarafi):** hozir `messages_content.dart` qidiruvni **klient tomonda**,
> faqat yuklangan suhbatlar `name`i bo'yicha filtrlaydi. Backend ulanganda bu `chats/search`ga
> (debounce ~300ms bilan) o'tkaziladi va UI ikki bo'limli ro'yxatga aylantiriladi:
> "Suhbatlar" va "Boshqa foydalanuvchilar".

### 7.8 Onlayn holat (presence)

Suhbatdosh avataridagi yashil nuqta uchun.

| Maydon | Ma'nosi |
|---|---|
| `is_online` | Hozir aktiv WebSocket ulanishi bormi |
| `last_seen_at` | Oxirgi marta onlayn bo'lgan vaqt (ISO 8601) |

- Foydalanuvchi **onlayn** hisoblanadi: kamida bitta aktiv WS ulanishi bo'lsa.
- Ulanish uzilganda — `is_online: false`, `last_seen_at` = uzilgan vaqt.
- Do'stlar ekranidagi "5 daqiqa oldin", "Kecha" kabi matnlar `last_seen_at`dan **klientda**
  hisoblanadi (backend tayyor matn yubormaydi — 3 tillilik sababli, 7.3 qoidasi bilan bir xil).
- Maxfiylik: "oxirgi ko'rilgan"ni yashirish sozlamasi kelajakda qo'shilsa, `last_seen_at: null`
  qaytariladi (Maxfiylik moduli).

### 7.9 Real-time (WebSocket) — ro'yxat uchun eventlar

Loyihada WebSocket klienti **allaqachon yozilgan**: `lib/data/network/socket_service.dart`
(avtomatik reconnect, ping, app lifecycle kuzatuvi bilan). Ro'yxat ekrani jonli yangilanishi
uchun backend quyidagi eventlarni yuborishi kerak:

| Event | Qachon | Payload (asosiy maydonlar) |
|---|---|---|
| `new_message` | Har yangi xabar (ikkala tomonga) | `chat_id`, `message` (7.3 shakli), `interlocutor` (agar suhbat ro'yxatda yangi bo'lsa), `unread_count` |
| `message_read` | Suhbatdosh o'qiganda | `chat_id`, `message_ids[]`, `read_at` (8.7) |
| `presence` | Foydalanuvchi onlayn/oflayn bo'lganda | `user_id`, `is_online`, `last_seen_at` |

- `new_message` kelganda ilova suhbatni ro'yxat tepasiga ko'taradi; suhbat ro'yxatda bo'lmasa
  (birinchi xabar) — **yangi element sifatida qo'shadi** (7.1-qoida).
- Event formati JSON, `type` maydoni bilan ajratiladi:
  `{ "type": "new_message", "data": { ... } }`.

> ⚠️ **XAVFSIZLIK — hozirgi kodda jiddiy kamchilik.** `socket_service.dart` serverga
> `ws://84.32.100.42/ws/{userId}` manzili bilan ulanadi — ya'ni **autentifikatsiya yo'q,
> faqat URL'dagi `userId`.** Bu holatda istalgan odam boshqa birovning `userId`sini qo'yib
> ulanib, uning barcha xabarlarini o'qiy oladi.
>
> **Talab:** WebSocket ulanishi **access token bilan** autentifikatsiya qilinishi shart —
> `wss://<host>/ws?token=<access_token>` (yoki `Authorization` header). `user_id` tokendan
> olinadi, URL'dan emas. Shuningdek `ws://` emas, **`wss://`** (TLS) ishlatilishi kerak.
> Flutter tarafida `socket_service.dart` shunga mos yangilanadi.

### 7.10 Vaqt formati

- Backend **har doim ISO 8601 UTC** qaytaradi (`"2026-07-18T14:32:00Z"`).
- UI'dagi `14:32`, `Kecha`, `Yak`, `Sha` ko'rinishlari **klientda** hisoblanadi (mahalliy vaqt
  zonasi + til bo'yicha). Backend tayyor matn yubormaydi.

### 7.11 Xatolik kodlari

| `error_code` | HTTP | Qachon |
|---|---|---|
| `CHAT_NOT_FOUND` | 404 | Suhbat mavjud emas yoki foydalanuvchi uning a'zosi emas |
| `USER_NOT_FOUND` | 404 | `POST /chats`da noto'g'ri `user_id` |
| `USER_BLOCKED` | 403 | Bloklangan foydalanuvchi bilan suhbat ochish |
| `CANNOT_CHAT_WITH_SELF` | 400 | O'zi bilan suhbat ochishga urinish |
| `VALIDATION_ERROR` | 400 | Qidiruvda bo'sh `query` |

---

## 8. Modul: Chat — suhbat ichi (3a–3d)

Ekranlar: `chat` (`chat_content.dart`, `chat_app_bar.dart`, `chat_composer.dart`),
`ui/items/chat_message_item.dart`, `modal/attachment_bottom_sheet.dart` (3b),
`modal/message_actions_sheet.dart` (3c).

### 8.1 Tarjima — MODULNING YURAGI

> Foydalanuvchi talabi: *"chat message'da bir yo'la originali va tarjima qilingani ham keladi —
> user originalini ko'raman desa, o'sha message'ga men UI'da originalini ko'rsatib qo'yishim
> uchun"*.

**Qat'iy qoida:** har bir matnli xabar javobda **ikkala matnni ham** olib keladi — qo'shimcha
so'rov (`translate` endpoint) **umuman kerak emas**. Foydalanuvchi 3c menyusidagi
"Tarjima qilinmagan asli" ni bosganda, ilova **allaqachon qo'lida bor** matnni ko'rsatadi —
tarmoqqa chiqmaydi, kutish yo'q.

```json
{
  "text_original":       "Hallo! Ihre Bestellung ist fertig 🎉",
  "original_language":   "de",
  "text_translated":     "Salom! Buyurtmangiz tayyor bo'ldi 🎉",
  "translated_language": "uz",
  "is_translated":       true
}
```

| Maydon | Izoh |
|---|---|
| `text_original` | Jo'natuvchi **qanday yozgan bo'lsa** — o'zgartirilmagan asl matn |
| `original_language` | Avtomatik aniqlangan til, **ISO 639-1** (`de`, `ja`, `it`, `fr`, `uz`, ...) |
| `text_translated` | **So'rov yuborayotgan foydalanuvchining tiliga** tarjima qilingan matn |
| `translated_language` | Tarjima tili — so'rovchining **`native_language`**idan olinadi (1.5-bo'lim) |
| `is_translated` | `false` bo'lsa tarjima bo'lmagan (tillar bir xil) → `text_translated` = `null` |

#### 8.1.1 Tarjima **ko'ruvchiga qarab** bo'ladi (per-viewer)

Bu eng muhim nuqta: bitta xabar ikki foydalanuvchida **turlicha** ko'rinadi.

| | Anna (de) ko'radi | Men (uz) ko'raman |
|---|---|---|
| Anna yozgan xabar | `text_original` (o'z so'zi) | `text_translated` (uz) + asli talab bo'yicha |
| Men yozgan xabar | `text_translated` (de) | `text_original` (o'z so'zim) |

- Backend **asl matnni** saqlaydi va har bir maqsad tili uchun tarjimani **cache**laydi
  (bir xil matn ikki marta tarjima qilinmasin).
- So'rov kelganda: `translated_language` = **so'rovchining `native_language`i** — ilova tili
  (`app_language`) emas. Ya'ni interfeysi inglizcha, ona tili nemis bo'lgan foydalanuvchiga
  xabarlar **nemis tiliga** tarjima qilinadi (1.5-bo'lim).

#### 8.1.2 UI qaysi matnni ko'rsatadi (klient qoidasi)

| Holat | Standart ko'rinadi | 3c menyusi |
|---|---|---|
| **Kiruvchi** xabar, `is_translated: true` | `text_translated` | "Tarjima qilinmagan asli" → `text_original`ga almashadi |
| **Kiruvchi** xabar, `is_translated: false` | `text_original` | "Tarjima qilinmagan asli" **ko'rsatilmaydi** |
| **Chiquvchi** (mening) xabarim | `text_original` (o'z so'zim) | "Tarjima qilinmagan asli" **ko'rsatilmaydi** |

> Bu qoida kodda allaqachon shunday: `chat_screen.dart` da
> `showTranslate = msg.type == ChatMsgType.text && !msg.isOutgoing` — ya'ni "asl nusxa" bandi
> faqat **kiruvchi matnli** xabarda chiqadi. Backend shunga mos ma'lumot beradi.

#### 8.1.3 Chegaraviy holatlar

- **Tarjima xizmati ishlamay qolsa:** xabar baribir yetkaziladi — `text_translated: null`,
  `is_translated: false`, `translation_status: "failed"`. UI asl matnni ko'rsatadi (xabar
  yo'qolmaydi). Backend keyinroq fon rejimida qayta urinib, tarjima tayyor bo'lganda
  `message_translated` WS eventini yuboradi (8.9).
- **Til aniqlanmasa** (emoji, raqam, juda qisqa matn): `original_language: null`,
  `is_translated: false` — tarjima qilinmaydi.
- **Foydalanuvchi tilini o'zgartirsa** (Sozlamalar → ilova tili): eski xabarlar yangi tilga
  qayta tarjima qilinadi (keyingi `GET /messages` so'rovida yangi `translated_language` bilan
  keladi). Klient chat kешini tozalashi kerak.
- Faqat `type == "text"` tarjima qilinadi. Ovozli xabar transkripsiyasi/tarjimasi bu bosqichga
  **kirmaydi** (UI'da transkript ko'rsatilmaydi) — kelajakda ko'rib chiqiladi.

### 8.2 `Message` obyekti (to'liq)

```json
{
  "id": 9812,
  "client_message_id": "b3f1c2a0-7d21-4f8e-9c11-2a5d0e4b7a99",
  "chat_id": 77,
  "type": "text",
  "is_outgoing": false,
  "sender_id": 15,

  "text_original": "Hallo! Ihre Bestellung ist fertig 🎉",
  "original_language": "de",
  "text_translated": "Salom! Buyurtmangiz tayyor bo'ldi 🎉",
  "translated_language": "uz",
  "is_translated": true,
  "translation_status": "done",

  "reply_to": {
    "id": 9810,
    "sender_id": 15,
    "sender_name": "Anna Müller",
    "type": "text",
    "preview_text": "Salom! Buyurtmangiz tayyor bo'ldi"
  },

  "meta": null,

  "status": "read",
  "created_at": "2026-07-18T14:33:00Z",
  "delivered_at": "2026-07-18T14:33:02Z",
  "read_at": "2026-07-18T14:33:40Z",
  "is_deleted": false
}
```

| Maydon | Izoh |
|---|---|
| `client_message_id` | Klient yaratgan UUID — 8.4-bo'lim (dublikat oldini olish) |
| `type` | `text` \| `image` \| `voice` \| `file` \| `product` \| `location` \| `contact` \| `invoice` \| `offer` \| `catalog` \| `business_card` — `ChatMsgType` enum bilan **aynan bir xil** |
| `is_outgoing` | So'rovchi yozganmi (`sender_id == joriy user`) |
| `reply_to` | Javob berilgan xabar — `null` bo'lsa oddiy xabar. `preview_text` — sitata uchun qisqa matn |
| `meta` | Turga xos ma'lumot — 8.3-bo'lim |
| `status` | `sent` \| `delivered` \| `read` (`ChatStatus` enumiga mos). **Faqat `is_outgoing: true` da ma'noli** |
| `read_at` | 3c'dagi "O'qilgan · Bugun 14:33" uchun |

> **`reply_to.preview_text` haqida:** kiruvchi matnli xabarga javob berilganda sitatada
> **tarjima qilingan** matn ko'rsatiladi (foydalanuvchi tushunishi uchun) — backend uni
> so'rovchi tiliga moslab qaytaradi. Matnsiz turlar uchun `preview_text: null` bo'ladi va
> klient o'z lokalizatsiya kalitini (`chat_preview_photo` va h.k.) ishlatadi — 7.3 qoidasi.

### 8.3 `meta` — tur bo'yicha tarkib

| `type` | `meta` | UI izohi |
|---|---|---|
| `text` | `null` | — |
| `image` | `{ "url", "thumbnail_url", "width", "height", "file_size" }` | Rasm pufakchasi |
| `voice` | `{ "url", "duration_seconds": 21, "waveform": [3,7,12,...] }` | `waveform` — **ixtiyoriy** peak massivi (0–100). Berilmasa klient dekorativ to'lqin chizadi |
| `file` | `{ "url", "file_name": "Shartnoma.pdf", "file_ext": "PDF", "file_size": 253952 }` | `248 KB · PDF` klientda formatlanadi (xom bayt keladi) |
| `product` | `{ "product_id": 501, "name": "Qo'lda to'qilgan sharf", "price": "24.00", "currency": "USD", "image_url": "...", "is_available": true }` | "Ko'rish" → 6.5 mahsulot detali |
| `location` | `{ "latitude": 41.31, "longitude": 69.28, "label": "Do'kon manzili" }` | **Masofa ("1.2 km") backenddan kelmaydi** — 8.3.1 |
| `contact` | `{ "contact_name": "Doniyor Karimov", "contact_phone": "+998 90 123 45 67", "contact_user_id": 88 }` | `contact_user_id` — agar bu odam ilovada bo'lsa (profiliga o'tish uchun), aks holda `null` |
| `invoice` | `{ "invoice_number", "items": [{ "name", "qty", "price" }], "total", "currency", "due_date", "pdf_url" }` | Hisob-faktura pufakchasi — 8.3.3 |
| `offer` | `{ "title", "description", "price", "currency", "valid_until" }` | Kommersiya taklifi («Taklif») |
| `catalog` | `{ "products": [ { "product_id", "name", "price", "currency", "image_url", "is_available" } ] }` | Bir nechta mahsulot — **snapshot** (8.3.2) |
| `business_card` | `{ "user_id", "company_name", "logo_url", "phone", "website", "country", "business_role" }` | Vizitka — 4.5 dan qisqartirilgan snapshot |

#### 8.3.1 Backenddan KELMAYDIGAN narsalar (klient hisoblaydi)

Bularni backend yubormasligi kerak — aks holda noto'g'ri bo'ladi:

| Narsa | Nega klientda |
|---|---|
| **Joylashuv masofasi** ("1.2 km") | Masofa **ko'ruvchining hozirgi joyiga** nisbatan — har foydalanuvchida boshqacha va har daqiqada o'zgaradi. Backend faqat `latitude`/`longitude` beradi |
| **Ovozli xabar "yuklab olingan"mi** (`voiceDownloaded`) | Bu **qurilma keshi** holati — fayl telefonda bormi yoki yo'qmi. Backend bilan aloqasi yo'q |
| **Vaqt ko'rinishi** (`14:33`, `Bugun`) | ISO'dan mahalliy vaqt zonasi + til bo'yicha klientda (7.10 qoidasi) |
| **Fayl hajmi matni** (`248 KB`) | Xom bayt (`253952`) keladi, formatlash klientda |
| **Sana ajratkichlari** ("Bugun", "Kecha") | `created_at` bo'yicha klientda guruhlanadi |
| **Valyuta belgisini formatlash** (`$24.00` / `24,00 €`) | Backend `price` + `currency` kodini beradi; lokal format klientda |
| **Invoice / offer «muddati o'tgan» badge** | `due_date` / `valid_until` dan klient hisoblaydi |

#### 8.3.2 Mahsulot xabari — snapshot qoidasi

`product` turidagi xabarda `meta` ichida mahsulotning **nusxasi (snapshot)** saqlanadi
(nom, narx, rasm) — faqat `product_id` emas.

**Sabab:** mahsulot keyin o'chirilishi, narxi o'zgarishi yoki sotuvchining obunasi tugashi
mumkin. Snapshot bo'lmasa eski suhbatdagi pufakcha bo'sh qolib ketadi. `is_available: false`
bo'lsa — UI kartani ko'rsatadi, lekin "Ko'rish" tugmasini o'chiradi.

**`catalog` uchun:** har bir `product_ids` elementi bo'yicha xuddi shu snapshot massivi
yig'iladi va `meta.products` ga yoziladi.

#### 8.3.3 Yangi biriktirish turlari — yaratish qoidalari

| `type` | Yuborish usuli | Alohida upload? |
|---|---|---|
| `offer` | `POST /chats/{id}/messages` — bodyda `type` + maydonlar | Yo'q |
| `catalog` | `POST .../messages` — `{ "type": "catalog", "product_ids": [501, 502] }` (max 10) | Yo'q — snapshot serverda |
| `business_card` | `POST .../messages` — `{ "type": "business_card" }` (o'z profili) yoki `user_id` | Yo'q — 4.5 dan snapshot |
| `invoice` | Qo'lda meta (asosiy) | PDF ixtiyoriy — 8.5 `file` + `pdf_url` |

> ✅ **QAROR (invoice):** **asosiy yo'l — qo'lda.**
> `POST /chats/{id}/messages` + `type: "invoice"` + meta (`invoice_number`, `items`,
> `total`, `currency`, `due_date`, `pdf_url?`). PDF kerak bo'lsa avval 8.5 upload.
>
> **Avto-generator** (`POST /chats/{id}/invoices` — deal/order dan PDF) — keyingi bosqich;
> v1 da shart emas. Deal Mode / stats invoice xabarlarini allaqachon hisoblaydi.

**Request namunalari (8.4 ga qo'shimcha):**

```json
{ "client_message_id": "…", "type": "offer", "title": "500 dona sharf", "description": "FOB Istanbul", "price": "4200.00", "currency": "USD", "valid_until": "2026-08-01" }
{ "client_message_id": "…", "type": "catalog", "product_ids": [501, 502, 503] }
{ "client_message_id": "…", "type": "business_card" }
{ "client_message_id": "…", "type": "invoice", "invoice_number": "INV-2026-014", "items": [{ "name": "Sharf", "qty": 100, "price": "12.00" }], "total": "1200.00", "currency": "USD", "due_date": "2026-08-15", "pdf_url": null }
```

### 8.4 `POST api/v1/chats/{chat_id}/messages` — xabar yuborish

> **Arxitektura qarori:** xabar **REST orqali yuboriladi**, **WebSocket orqali qabul qilinadi.**
> Sabab: REST'da qayta urinish (retry), xatolik kodlari va fayl yuklash ancha ishonchli;
> mavjud `SocketService.send()` esa faqat `{action, topic}` yuborishga mo'ljallangan va xabar
> yuborishga yaramaydi. WS — faqat kelayotgan yangilanishlar uchun.

**Request (matn):**

```json
{
  "client_message_id": "b3f1c2a0-7d21-4f8e-9c11-2a5d0e4b7a99",
  "type": "text",
  "text": "Rahmat! Hoziroq yetib boraman.",
  "reply_to_id": 9810
}
```

**Request (media/boshqa turlar)** — avval fayl yuklanadi (8.5), keyin:

```json
{
  "client_message_id": "…",
  "type": "voice",
  "media_id": 4410,
  "reply_to_id": null
}
```

```json
{ "client_message_id": "…", "type": "product",  "product_id": 501 }
{ "client_message_id": "…", "type": "location", "latitude": 41.31, "longitude": 69.28, "label": "Mening joylashuvim" }
{ "client_message_id": "…", "type": "contact",  "contact_name": "Doniyor Karimov", "contact_phone": "+998 90 123 45 67" }
```

**Response `201`:** 8.2-bo'limdagi to'liq `Message` (jo'natuvchi nuqtai nazaridan —
`is_outgoing: true`, `status: "sent"`).

**`client_message_id` nega kerak:**
- Klient xabarni **darhol** ekranga chiqaradi (optimistik UI), keyin javob kelganda haqiqiy
  `id` bilan almashtiradi.
- WS orqali kelgan echo shu `client_message_id` bo'yicha taniladi → **dublikat pufakcha
  chiqmaydi**.
- Tarmoq uzilib qayta yuborilsa — backend shu `id` bo'yicha **takrorni rad etadi**
  (idempotent), bitta xabar ikki marta ketmaydi.

**Xatoliklar:** `403 USER_BLOCKED`, `404 CHAT_NOT_FOUND`, `400 VALIDATION_ERROR`
(bo'sh matn yoki `media_id` topilmasa), `413 FILE_TOO_LARGE`.

> **Eslatma:** birinchi xabar yuborilgach suhbat **ikkala tomonning ro'yxatida** paydo bo'ladi
> (7.1-qoida).

### 8.5 `POST api/v1/chats/media` — fayl yuklash (rasm / ovoz / hujjat)

`multipart/form-data`: `file` + `type` (`image` \| `voice` \| `file`).

**Response `201`:**

```json
{ "id": 4410, "url": "https://cdn.anylang.uz/chat/4410.m4a", "meta": { "duration_seconds": 21 } }
```

| Tur | Formatlar | Maksimal hajm |
|---|---|---|
| `image` | JPEG, PNG, WebP, HEIC | 10 MB |
| `voice` | m4a, aac, ogg, mp3 | 20 MB (maksimal 5 daqiqa) |
| `file` | Har qanday | 50 MB |

- Server rasm uchun `thumbnail_url` yasaydi, ovoz uchun `duration_seconds`ni **o'zi aniqlaydi**
  (klientga ishonmaydi).
- 24 soat ichida hech qaysi xabarga biriktirilmagan fayl avtomatik o'chiriladi (6.6 bilan bir xil).
- Yuklangan faylni faqat **yuklagan foydalanuvchi** xabarga biriktira oladi.

### 8.6 `GET api/v1/chats/{chat_id}/messages` — xabarlar tarixi

| Query | Izoh |
|---|---|
| `limit` | Standart 30, maksimal 100 |
| `before_id` | Shu `id`dan **eskiroq** xabarlar (yuqoriga scroll qilganda) |
| `after_id` | Shu `id`dan **yangiroq** xabarlar (uzilishdan keyin sinxronlash uchun) |

**Response `200`:**

```json
{
  "items": [ { "...": "8.2-dagi Message" } ],
  "has_more": true,
  "chat": {
    "id": 77,
    "interlocutor": { "id": 15, "full_name": "Anna Müller", "avatar_url": "...", "is_online": true, "last_seen_at": "..." }
  }
}
```

- `items` — **eskidan yangiga** tartibda (ro'yxat pastga qarab o'sadi, UI shunday chizadi).
- `chat.interlocutor` — app bar (ism, avatar, "onlayn") uchun; shu tufayli chat ekrani
  ochilganda **bitta so'rov** yetadi.
- Barcha matnli xabarlar 8.1 bo'yicha **ikkala matn bilan** keladi.
- O'chirilgan xabarlar qaytmaydi (`is_deleted: true` bo'lganlar filtrlanadi).

### 8.7 O'qilganlik mexanizmi (read receipts) — batch qilib yuborish

**Qoida:** xabar chat ochilishi bilan emas, **ekranda haqiqatan ko'ringanda** o'qilgan bo'ladi.
Har bir xabar uchun alohida so'rov yuborilmaydi — ko'ringan xabarlar ID'lari **to'planib**,
bitta so'rovda yuboriladi.

#### 8.7.1 `POST api/v1/chats/{chat_id}/read`

**Request:**

```json
{ "message_ids": [9805, 9807, 9812] }
```

**Response `200`:**

```json
{
  "read_message_ids": [9805, 9807, 9812],
  "unread_count": 4,
  "read_at": "2026-07-18T14:33:40Z"
}
```

**Backend qoidalari:**

| Qoida | Tafsilot |
|---|---|
| **Faqat suhbatdosh xabarlari** | Ro'yxatdagi **o'z** xabarlari (`sender_id == joriy user`) **jimgina o'tkazib yuboriladi** — xato qaytarilmaydi |
| **Idempotent** | Allaqachon o'qilgan ID qayta kelsa — xato emas, `read_at` **o'zgarmaydi** (birinchi o'qilgan vaqt saqlanadi) |
| **Notanish ID** | Bu chatga tegishli bo'lmagan yoki o'chirilgan ID — jimgina e'tiborsiz qoldiriladi (butun so'rov yiqilmaydi) |
| **`unread_count`** | Amaldan **keyingi** haqiqiy qiymat qaytadi — klient badge'ni shunga sinxronlaydi (o'zi hisoblab yurmaydi) |
| **Limit** | Bitta so'rovda maksimal **100 ta** ID (`400 TOO_MANY_MESSAGE_IDS`) |
| **WS** | Faqat **haqiqatan holati o'zgargan** ID'lar uchun jo'natuvchiga `message_read` eventi ketadi (8.9) |

#### 8.7.2 Klient qoidalari (Flutter tomoni)

| Qoida | Qiymat / sabab |
|---|---|
| **"Ko'rindi" mezoni** | Xabar kamida **50%** ko'rinib, kamida **500 ms** ekranda tursa. Aks holda tez scroll qilganda hamma xabar "o'qilgan" bo'lib ketadi |
| **Faqat foreground** | Ilova fonga o'tgan bo'lsa hisoblanmaydi |
| **Buferlash (debounce)** | Ko'ringan ID'lar buferga yig'iladi va **500 ms** jimlikdan keyin **bitta** so'rovda yuboriladi. Bufer **20 ta**ga to'lsa — kutmasdan yuboriladi |
| **Darhol yuborish** | Chat yopilganda yoki ilova fonga o'tganda bufer **shu zahoti** bo'shatiladi (aks holda ID'lar yo'qoladi) |
| **Dublikat yubormaslik** | Serverdan tasdiq kelgan ID'lar qayta yuborilmaydi |
| **Xatolikda** | So'rov muvaffaqiyatsiz bo'lsa ID'lar buferda **qoladi** va keyingi urinishda qayta ketadi — endpoint idempotent bo'lgani uchun bu xavfsiz |
| **O'z xabarlari** | Buferga umuman qo'shilmaydi |

#### 8.7.3 Nega ID ro'yxati (watermark emas)

Muqobil yondashuv bor edi — faqat **eng oxirgi o'qilgan ID**ni yuborish
(`last_read_message_id`) va backend `id <= X` bo'lganlarning hammasini o'qilgan qilishi.

**U tanlanmadi**, chunki: chat pastdan (eng yangi xabardan) ochiladi, shuning uchun watermark
yuborilsa — foydalanuvchi **ko'rmagan**, tepada qolib ketgan eski o'qilmagan xabarlar ham
avtomatik "o'qilgan" bo'lib qolardi. Talab esa — **faqat haqiqatan ko'ringanini** belgilash.

**Buning oqibati (bilib turish kerak):** foydalanuvchi 50 ta o'qilmagan xabarni tepaga scroll
qilmasdan pastda tursa — o'sha ko'rilmaganlar **o'qilmagan bo'lib qolaveradi** va badge
nolga tushmaydi. Bu **to'g'ri xulq** (Telegramdagi kabi). Agar keyinchalik "hammasini o'qilgan
deb belgilash" tugmasi kerak bo'lsa — shu endpointga `{ "mark_all": true }` bayrog'i qo'shiladi.

### 8.8 Xabar ustidagi amallar (3c menyusi)

| Menyu bandi | Endpoint / xatti-harakat |
|---|---|
| **Tarjima qilinmagan asli** | **So'rov yo'q** — `text_original` allaqachon qo'lda (8.1) |
| **Javob berish** | So'rov yo'q — keyingi yuborishda `reply_to_id` beriladi |
| **Nusxa olish** | So'rov yo'q — klient buferi |
| **O'chirish** | `DELETE api/v1/messages/{id}` |

**`DELETE api/v1/messages/{id}`**

**Response `200`:** `{ "id": 9812, "deleted_for_everyone": true }`

- **O'z xabaring** → ikkala tomondan ham o'chadi (`deleted_for_everyone: true`), suhbatdoshga
  `message_deleted` WS eventi ketadi.
- **Suhbatdoshning xabari** → faqat **o'zingdan** o'chadi (`deleted_for_everyone: false`),
  unda qolaveradi.
- Soft delete: yozuv bazada qoladi (`is_deleted`), lekin ro'yxatlarda qaytmaydi.
- O'chirilgan xabar suhbatning **oxirgi xabari** bo'lsa — suhbatlar ro'yxatidagi
  `last_message` bir oldingisiga yangilanadi va `chat_updated` eventi yuboriladi.

### 8.9 WebSocket eventlari (chat ekrani uchun)

7.9-bo'limdagi eventlarga qo'shimcha:

| Event | Qachon | `data` tarkibi |
|---|---|---|
| `new_message` | Yangi xabar | To'liq `Message` (qabul qiluvchi nuqtai nazaridan, **tarjimasi bilan**) + `chat_id` |
| `message_read` | Suhbatdosh xabar(lar)ni o'qidi | `chat_id`, **`message_ids[]`**, `read_at` — jo'natuvchi **aynan shu** xabarlarda ✓✓ qo'yadi (8.7) |
| `message_deleted` | Xabar o'chirildi | `chat_id`, `message_id` |
| `message_translated` | Kechikkan tarjima tayyor bo'ldi (8.1.3) | `message_id`, `text_translated`, `translated_language` |
| `typing` | Suhbatdosh yozmoqda | `chat_id`, `user_id`, `is_typing` |

- `typing` — klient yozayotganda ~3 soniyada bir marta yuboradi, 5 soniya jimlikdan keyin
  `is_typing: false`. **UI'da hali yozilmagan** (`anylang_mobile.md`) — backend tayyor tursin.
- Barcha eventlar `{ "type": "...", "data": { ... } }` shaklida.
- ⚠️ WebSocket autentifikatsiyasi bo'yicha **7.9-bo'limdagi xavfsizlik talabi** shu modulga ham
  to'liq taalluqli (token bilan ulanish, `wss://`).

### 8.10 Xatolik kodlari

| `error_code` | HTTP | Qachon |
|---|---|---|
| `CHAT_NOT_FOUND` | 404 | Suhbat yo'q yoki foydalanuvchi a'zosi emas |
| `TOO_MANY_MESSAGE_IDS` | 400 | `read` so'rovida 100 tadan ko'p ID (8.7) |
| `MESSAGE_NOT_FOUND` | 404 | O'chirish/javob berishda noto'g'ri `id` |
| `USER_BLOCKED` | 403 | Bloklangan foydalanuvchiga yozish |
| `FILE_TOO_LARGE` | 413 | 8.5-dagi limitdan oshsa |
| `UNSUPPORTED_FILE_TYPE` | 400 | Ruxsat etilmagan format |
| `MEDIA_NOT_FOUND` | 400 | `media_id` mavjud emas yoki boshqa foydalanuvchiniki |
| `VOICE_TOO_LONG` | 400 | 5 daqiqadan uzun ovozli xabar |
| `VALIDATION_ERROR` | 400 | Bo'sh matn, noto'g'ri koordinata va h.k. |
| `PRODUCT_IDS_LIMIT` | 400 | `catalog` da 10 tadan ko'p `product_ids` |
| `PRODUCT_NOT_FOUND` | 404 | `catalog` / `product` da mavjud bo'lmagan mahsulot |
| `SUGGEST_REPLIES_FAILED` | 502 | LLM / AI gateway xatosi (8.11) |
| `RATE_LIMITED` | 429 | Smart Reply juda tez-tez so'ralganda |

### 8.11 AI Smart Reply — `POST api/v1/chats/{chat_id}/suggest-replies`

Kiruvchi xabarga tayyor javob variantlari (Professional / Do'stona / Savdo / Muzokara).

**Request:**

```json
{
  "message_id": 9812
}
```

**Response `200`:**

```json
{
  "suggestions": [
    { "tone": "professional", "text": "Rahmat. Taklifingizni ko'rib chiqamiz va bugun javob beramiz." },
    { "tone": "friendly", "text": "Zo'r! Tez orada qaytaman 😊" },
    { "tone": "sales", "text": "Ajoyib. Minimal buyurtma 200 dona — narxni yuboraymi?" },
    { "tone": "negotiation", "text": "Narxni biroz pasaytirsak kelishuvimiz mumkin. Qanday chegirma taklif qilasiz?" }
  ]
}
```

#### 8.11.1 `tone` — enum va til xaritasi

| Kod | uz_UZ | ru_RU | us_US |
|---|---|---|---|
| `professional` | Professional javob | Деловой ответ | Professional |
| `friendly` | Do'stona javob | Дружеский ответ | Friendly |
| `sales` | Savdo uslubida | В стиле продаж | Sales |
| `negotiation` | Muzokara uslubida | Переговорный стиль | Negotiation |

**Qoidalar:**
- `message_id` shu chatga tegishli bo'lishi shart; aks holda `404 MESSAGE_NOT_FOUND`.
- Kontekst: oxirgi **5–10** ta xabar (`text_original` / tarjima) + so'rovchining
  `native_language` — javob **so'rovchi tilida**.
- LLM (Claude / OpenAI / ichki gateway) — tashqi chaqiruv, timeout majburiy (1.0).
- Tavsiyalar **saqlanmaydi** — har so'rovda yangidan generatsiya.
- Foydalanuvchi tanlagan matnni yuborish — oddiy `POST .../messages` (`type: text`).
- Tarif: Basic da kunlik limit (masalan 10) — `429 RATE_LIMITED`; Premium/Business cheksiz
  (5.1 bilan bog'lanishi mumkin).

### 8.12 Aniqlangan UI gap'lar (8-bo'lim qo'shimchalari)

| UI | Backend | Izoh |
|---|---|---|
| Invoice / Taklif / Katalog / Vizitka pufakchalari | 8.3 yangi typelar | Snapshot qoidalari |
| Smart Reply stillar sheet | 8.11 | Tone enum lokalizatsiya klientda |
| Invoice (qo'lda meta) | 8.3.3 QAROR | Avto PDF — keyin |
| Catalog max 10 | `PRODUCT_IDS_LIMIT` | |

---

## 9. Modul: Do'stlar (Friends)

Ekranlar: `friends` (UI tabi «Tarmoq» — **12.0 QAROR**),
`add_friend` (Hamkor/do'st qo'shish), `ui/items/friend_result_item.dart` / `user_card_item.dart`.

> **Bog'lanish:** pastki tab — **«Tarmoq»**. Friendship `pending`/`accepted` — **9-bo'lim**;
> B2B trust, risk, viewers, filtrlar — **12-bo'lim**.

### 9.0 Do'stlik holati (state machine) — ASOSIY LOGIKA

> Foydalanuvchi talabi: *"do'st bo'lishga so'rov yuboriladi, so'rov qabul qilinsa do'stlar
> ro'yxatiga qo'shiladi; so'rov yuborilgan va javob berilmagan bo'lsa — pending; rad etilsa
> **yana qayta yuborsa ham bo'ladi** — 'bekor qildi, endi yubora olmaysan' emas."*

Ikki foydalanuvchi o'rtasidagi munosabat **bitta yozuv** (`friendship`) bilan ifodalanadi:

| `status` | Ma'nosi | UI tugmasi (`FriendActionState`) |
|---|---|---|
| `none` | Munosabat yo'q (yoki rad etilgan/bekor qilingan) | **"Qo'shish"** (`add`) |
| `pending` | So'rov yuborilgan, javob kutilmoqda | Yuboruvchida: **"So'rov yuborildi"** (`requested`, bosilmaydi)<br>Qabul qiluvchida: **"Qabul qilish"** (`anylang_mobile.md`) |
| `accepted` | Do'st bo'lishdi | **"Yozish"** (`message`) |

**O'tishlar:**

```
none ──(so'rov yuborish)──► pending ──(qabul qilish)──► accepted
                              │                            │
                              ├──(rad etish)───► none      │
                              └──(bekor qilish)─► none     │
                                                            │
                              none ◄──(do'stlikdan chiqarish)┘
```

**Qat'iy qoidalar:**

1. **Rad etish — yakuniy emas.** `declined` degan doimiy holat **yo'q** — rad etilgan so'rov
   munosabatni `none` ga qaytaradi, ya'ni **qayta so'rov yuborish mumkin** (foydalanuvchi
   talabi). Faqat *bloklash* (Maxfiylik moduli) qat'iy to'siq bo'ladi.
2. **Bekor qilish (withdraw)** ham `none` ga qaytaradi — qayta yuborsa bo'ladi.
3. **O'zaro so'rov = avtomatik do'stlik.** A → B ga so'rov yuborgan bo'lsa va B ham A ga
   so'rov yuborsa — ikkinchi so'rov **darhol `accepted`** ga aylanadi (qabul qilish bosqichi
   o'tkazib yuboriladi). Bu Telegram/LinkedIn xulqi.
4. **Munosabat simmetrik:** `accepted` bo'lgach ikkalasi ham bir-birining do'stlar ro'yxatida
   ko'rinadi. `pending` esa **yo'nalishli** — kim yuborganini eslab qolish shart
   (`requester_id`).
5. **Do'stlik — chat uchun shart EMAS.** 7.5-bo'lim bo'yicha istalgan foydalanuvchiga yozish
   mumkin (mahsulotdagi "Bog'lanish" ham shunga tayanadi). Do'stlar ro'yxati — qulaylik
   (kontaktlar), cheklov emas.

#### 9.0.1 Spam himoyasi (qayta yuborish cheklovi) — TAVSIYA

Rad etilgandan keyin qayta yuborish ochiq bo'lgani uchun, bu **bezovta qilish (harassment)
yo'li** bo'lib qolmasligi kerak. Tavsiya etiladigan yumshoq cheklov:

| Qoida | Qiymat |
|---|---|
| Rad etilgandan keyin qayta yuborish | **24 soat** kutish (`429 FRIEND_REQUEST_COOLDOWN`, javobda `retry_after_seconds`) |
| Bitta juftlik uchun rad etishlar soni | 3 martadan keyin kutish **7 kun**ga uzayadi |
| Umumiy limit | Bir foydalanuvchi kuniga maksimal **50 ta** so'rov yuborishi mumkin |

> Bu **taklif** — biznes qarori sizniki. Agar umuman cheklov kerak bo'lmasa, backend bu
> qoidalarni o'chirib qo'yishi mumkin: asosiy talab (**rad etilsa qayta yuborish mumkin**)
> baribir bajariladi. Cheklov faqat *tezlikni* chegaralaydi, *imkoniyatni* emas.

### 9.1 `Friend` obyekti (do'stlar ro'yxati elementi)

```json
{
  "id": 15,
  "full_name": "Anna Müller",
  "number": "7831111",
  "avatar_url": "https://cdn.anylang.uz/avatars/15.jpg",
  "is_online": true,
  "last_seen_at": "2026-07-18T14:20:00Z",
  "native_language": "de",
  "country": "DE",
  "is_business": false,
  "verified_badge": false,
  "friends_since": "2026-05-02T09:12:00Z"
}
```

**MUHIM — `status` matni backenddan kelmaydi.** Kodda `Friend.status` maydoni
`"Onlayn · Nemis"` yoki `"5 daqiqa oldin · Yapon"` ko'rinishida. Bu **tayyor matn emas**,
klient uni ikki qismdan yig'adi:

| Qism | Manba | Kim yasaydi |
|---|---|---|
| `"Onlayn"` / `"5 daqiqa oldin"` / `"Kecha"` | `is_online` + `last_seen_at` | **Klient** (7.8 va 7.10 qoidalari — 3 tillilik sababli) |
| `"Nemis"` / `"Yapon"` | `native_language` (`de` / `ja`) | **Klient** — lokalizatsiyadagi til nomlari (`lang_name_*`) |

### 9.2 `GET api/v1/friends` — do'stlar ro'yxati

| Query | Izoh |
|---|---|
| `search` | **O'z do'stlari** ichidan ism yoki raqam bo'yicha filtr (ixtiyoriy). Bu — o'z ro'yxati bo'lgani uchun ism bilan qidirish ruxsat etiladi |
| `page`, `limit` | Standart `limit=50`, maksimal 100 |

**Response `200`:**

```json
{
  "items": [ { "...": "9.1-dagi Friend" } ],
  "page": 1,
  "limit": 50,
  "total": 24,
  "has_more": false,
  "online_count": 3,
  "pending_incoming_count": 2
}
```

- **Guruhlash ("ONLAYN — 3" / "BOSHQALAR") klientda** bajariladi — backend bitta tekis ro'yxat
  qaytaradi. Sabab: onlayn holat WS `presence` eventi bilan **real vaqtda o'zgaradi**, server
  guruhlagani bilan bir soniyada eskiradi. `online_count` faqat qulaylik uchun.
- Saralash: avval **onlayn**lar, keyin `last_seen_at` bo'yicha yangidan eskiga.
- `pending_incoming_count` — kelgan (javob berilmagan) so'rovlar soni. Do'stlar tabiga yoki
  "do'st qo'shish" tugmasiga belgi (badge) qo'yish uchun — hozir UI'da yo'q, lekin kerak
  bo'ladi (`anylang_mobile.md`).
- Bloklangan foydalanuvchilar ro'yxatda ko'rinmaydi.

### 9.3 `GET api/v1/users/search` — foydalanuvchi qidirish (Do'st qo'shish ekrani)

> **Diqqat:** bu **`GET /chats/search` (7.7) dan boshqa endpoint.** Ular chalkashtirilmasin:
>
> | Endpoint | Ekran | Nima qaytaradi |
> |---|---|---|
> | `GET /chats/search` | Xabarlar (S13) | **2 ta ro'yxat**: mavjud suhbatlar + yozishmaganlar |
> | `GET /users/search` | Do'st qo'shish | **1 ta ro'yxat**: har element `friendship_status` bilan |

#### 9.3.0 Faqat raqam bo'yicha qidiriladi

Yangi do'st **ismi bilan topilmaydi** — faqat **AnyLang raqami** orqali (11-bo'lim).
Bu chat qidiruvdagi qoida (7.7.0) bilan bir xil mantiq: begona odamni ismidan qidirib
topib bo'lmaydi.

- `query` faqat raqamlardan iborat bo'lishi kerak (bo'sh joy/`-` e'tiborsiz).
- Matn yuborilsa → `400 NUMBER_QUERY_REQUIRED`, javobda
  `{ "message": "Foydalanuvchini raqami orqali qidiring" }`. UI shu xabarni ko'rsatadi.
- Kamida **3 raqam**; qisman (prefiks) moslik ishlaydi.

> **UI o'zgarishi:** qidiruv maydonining hint matni `add_friend_search_hint`
> (*"ism, @username, telefon"*) → **"Raqam bilan qidiring"** ga o'zgartiriladi, klaviatura
> raqamli (`TextInputType.number`) bo'ladi (`anylang_mobile.md`).

**Query:**

| Parametr | Izoh |
|---|---|
| `query` | **Majburiy — faqat raqam** (kamida 3 ta) |
| `page`, `limit` | Standart `limit=30` |

**Response `200`:**

```json
{
  "items": [
    {
      "id": 31,
      "full_name": "Chen Long",
      "number": "4862793",
      "avatar_url": null,
      "is_online": false,
      "last_seen_at": "2026-07-18T09:10:00Z",
      "native_language": "zh",
      "country": "CN",
      "is_business": false,
      "verified_badge": false,
      "friendship_status": "none",
      "friendship_request_id": null,
      "is_request_incoming": false
    },
    {
      "id": 44,
      "full_name": "Ahmad Karimov",
      "number": "7834455",
      "friendship_status": "pending",
      "friendship_request_id": 7781,
      "is_request_incoming": false,
      "...": "..."
    }
  ],
  "page": 1, "limit": 30, "total": 5, "has_more": false
}
```

**Qidiruv qoidalari:**

| Maydon | Qoida |
|---|---|
| `number` | Bo'sh joy va `-` e'tiborsiz (`"783 11 11"` = `"7831111"`). **Prefiks bo'yicha qisman moslik**, kamida 3 raqam |
| Ism | **Qidirilmaydi** (9.3.0) |

- O'zini (`is_self`) natijaga qo'shmaydi.
- Bloklangan / bloklagan foydalanuvchilar chiqmaydi.
- `is_active: false` hisoblar chiqmaydi.
- `friendship_status` — 9.0-dagi 3 holatdan biri; `is_request_incoming` — `pending` bo'lganda
  so'rovni **kim yuborganini** bildiradi (`true` = menga kelgan).
- `friendship_request_id` — `pending` bo'lsa qabul/rad/bekor qilish uchun kerak.

**UI tugmasi qanday tanlanadi:**

| `friendship_status` | `is_request_incoming` | Tugma |
|---|---|---|
| `none` | — | "Qo'shish" → `POST /friends/requests` |
| `pending` | `false` | "So'rov yuborildi" (bosilmaydi) |
| `pending` | `true` | **"Qabul qilish"** → accept (UI'da hali yo'q — `anylang_mobile.md`) |
| `accepted` | — | "Yozish" → `POST /chats` (7.5) |

#### 9.3.1 Raqam bo'yicha qidiruv — xavfsizlik

Prefiks bo'yicha qisman moslik qulay, lekin uni cheklamasa uchinchi tomon raqamlarni
**ketma-ket sinab (enumeration)** butun bazani yig'ib olishi mumkin. Shuning uchun:

| Cheklov | Qiymat |
|---|---|
| Minimal uzunlik | **3 raqam** (`"7"` yozib hammani ko'rib bo'lmaydi) |
| Rate limit | Daqiqada **20 ta** so'rov (7.7.3 bilan bir xil) |
| Natija limiti | Bitta so'rovda maksimal **30 ta** foydalanuvchi |

Kelajakda "meni raqam orqali topishmasin" maxfiylik sozlamasi qo'shilsa — bunday foydalanuvchi
natijaga chiqmaydi (Maxfiylik moduli).

### 9.4 Do'stlik so'rovlari

#### `POST api/v1/friends/requests` — so'rov yuborish

**Request:** `{ "user_id": 31 }`

**Response `201`:**

```json
{ "id": 7781, "user_id": 31, "status": "pending", "created_at": "2026-07-20T10:00:00Z" }
```

**O'zaro so'rov holati** (9.0-qoida 3) — darhol do'st bo'ladi:

```json
{ "id": 7781, "user_id": 31, "status": "accepted", "auto_accepted": true, "created_at": "..." }
```

| Xatolik | HTTP | Qachon |
|---|---|---|
| `ALREADY_FRIENDS` | 409 | Allaqachon do'st |
| `REQUEST_ALREADY_SENT` | 409 | Javob berilmagan so'rov bor |
| `FRIEND_REQUEST_COOLDOWN` | 429 | 9.0.1 cheklovi (`retry_after_seconds` bilan) |
| `CANNOT_FRIEND_SELF` | 400 | O'ziga so'rov |
| `USER_BLOCKED` | 403 | Bloklangan / bloklagan |
| `USER_NOT_FOUND` | 404 | — |

#### `POST api/v1/friends/requests/{id}/accept`

**Response `200`:** `{ "id": 7781, "status": "accepted", "friend": { "...": "9.1-dagi Friend" } }`
- Javobda to'liq `Friend` qaytadi — klient do'stlar ro'yxatiga **qayta so'rovsiz** qo'shadi.
- Yuboruvchiga `friend_request_accepted` WS eventi ketadi (9.5).

#### `POST api/v1/friends/requests/{id}/decline` — rad etish

**Response `200`:** `{ "id": 7781, "status": "none" }`
- Munosabat **`none`** ga qaytadi — `declined` holati saqlanmaydi (9.0-qoida 1).
- Backend faqat spam himoyasi uchun rad etish **vaqti va sonini** ichki hisobda saqlaydi
  (9.0.1); bu foydalanuvchiga ko'rinmaydi.
- Yuboruvchiga **xabar berilmaydi** (u "So'rov yuborildi" o'rniga yana "Qo'shish" ko'radi,
  rad etilganini bilmaydi) — odatiy va odobli xulq.

#### `DELETE api/v1/friends/requests/{id}` — o'z so'rovini bekor qilish

**Response `200`:** `{ "id": 7781, "status": "none" }`
- Faqat **o'zi yuborgan** `pending` so'rovni bekor qila oladi (`403 NOT_REQUEST_OWNER`).

#### `GET api/v1/friends/requests` — so'rovlar ro'yxati

| Query | Izoh |
|---|---|
| `type` | `incoming` (standart) \| `outgoing` |
| `page`, `limit` | — |

**Response `200`:**

```json
{
  "items": [
    {
      "id": 7781,
      "user": { "...": "9.1-dagi Friend shakli (friends_since'siz)" },
      "created_at": "2026-07-20T10:00:00Z"
    }
  ],
  "total": 2, "has_more": false
}
```

> ⚠️ **Bu endpointga mos ekran ilovada YO'Q** — `anylang_mobile.md` (9-bo'lim) ga qarang.

#### `DELETE api/v1/friends/{user_id}` — do'stlikdan chiqarish

**Response `200`:** `{ "user_id": 15, "status": "none" }`
- Ikkala tomondan ham o'chadi (simmetrik). Suhbat va xabarlar **saqlanadi**.
- Qayta so'rov yuborish mumkin (cheklovsiz — bu rad etish emas).

### 9.5 WebSocket eventlari

| Event | Qachon | `data` |
|---|---|---|
| `friend_request_received` | Kimdir so'rov yubordi | `request_id`, `user` (9.1 shakli) |
| `friend_request_accepted` | So'rovim qabul qilindi | `request_id`, `friend` (9.1 shakli) |
| `friend_removed` | Do'stlikdan chiqarildi | `user_id` |
| `presence` | Onlayn/oflayn (7.9 bilan bir xil) | `user_id`, `is_online`, `last_seen_at` |

- `friend_request_received` — Sozlamalardagi **"Do'st so'rovlari"** bildirishnoma tugmasi
  (`settings_notif_friend_requests`) shu eventga/push'ga bog'lanadi.
- Rad etish uchun event **yo'q** (yuqoridagi qoida).

---

## 10. Modul: Jonli muloqot (Live — og'zaki tarjima)

Ekran: `jonli` (`jonli_content.dart`, `jonli_state.dart`, `jonli_action.dart`),
`modal/language_bottom_sheet.dart` (til tanlash).

### 10.0 Oqim va asosiy tushuncha

**Bu — bitta telefon, ikki odam.** Suhbatdosh ilovada ro'yxatdan o'tgan foydalanuvchi **emas** —
u shunchaki yonda turgan, boshqa tilda gapiradigan odam. Shuning uchun Jonli sessiya
**bitta foydalanuvchiga** tegishli (ikkinchi hisob yo'q, WebSocket ham shart emas).

```
1. Foydalanuvchi tillarni tanlaydi:  mening tilim (uz)  ↔  suhbatdosh tili (en)
2. "Siz" tugmasini bosib turadi → ovoz yoziladi
3. Qo'yib yuboradi → audio backendga ketadi
4. Backend:  STT (uz)  →  tarjima (uz→en)  →  TTS (en)
5. Javob: asl matn + tarjima matni + tarjima audiosi (URL)
6. Ilova audioni ovoz chiqarib o'ynatadi — suhbatdosh ingliz tilida eshitadi
7. Suhbatdosh "Suhbatdosh" tugmasini bosib javob beradi → hammasi teskari yo'nalishda
```

**STT va TTS'ni to'liq backend bajaradi** — ilova faqat audio faylni yuboradi va qaytgan
audioni o'ynatadi. Flutter tarafda hech qanday nutq tanish/sintez kutubxonasi kerak emas.

**Klient tomonda qoladigan narsalar (backendga aloqasi yo'q):**

| Narsa | Izoh |
|---|---|
| `JonliMode` (`idle` / `me` / `other`) | Faqat UI holati — yozilyaptimi yoki yo'qmi. Backend bilmaydi va bilishi shart emas |
| To'lqin animatsiyasi, "Tinglanmoqda…" | Dekorativ |
| Tillarni almashtirish tugmasi (⇄) | Klientda almashtiriladi, keyin sessiya yangilanadi (10.3) |

### 10.1 Obuna cheklovi — Jonli faqat Premium/Business

> ✅ **QAROR:** Basic da Jonli **yo'q** → `403 SUBSCRIPTION_REQUIRED` (`required_plan: premium`).
> Tekshiruv sessiya yaratishda va har turn'da. UI: Basic tab → «Premium kerak» (`anylang_mobile.md`).

**5.1-bo'limdagi tariflar jadvaliga ko'ra:** Basic (bepul) tarifda *"Jonli muloqot rejimi"*
xususiyati **`included: false`**.

| Tarif | Jonli rejim | Kunlik limit |
|---|---|---|
| `basic` | ❌ Yo'q → `403 SUBSCRIPTION_REQUIRED` | — |
| `premium` | ✅ Bor | Cheksiz |
| `business` | ✅ Bor | Cheksiz |

- Tekshiruv **sessiya yaratishda ham, har turn'da ham** bajariladi (obuna o'rtada tugab
  qolishi mumkin).
- `403` javobida `{ "error_code": "SUBSCRIPTION_REQUIRED", "required_plan": "premium" }`
  qaytariladi — ilova foydalanuvchini Tariflar ekraniga (S16) yo'naltiradi.

### 10.2 `GET api/v1/live/languages` — qo'llab-quvvatlanadigan tillar

Til tanlash oynasi (S28) hozir **7 ta** tilni ko'rsatadi, lekin STT/TTS har bir til uchun
mavjud bo'lmasligi mumkin. Shuning uchun ro'yxat **backenddan** keladi.

**Response `200`:**

```json
{
  "languages": [
    { "code": "uz", "stt": true,  "tts": true,  "tts_voices": ["female", "male"] },
    { "code": "en", "stt": true,  "tts": true,  "tts_voices": ["female", "male"] },
    { "code": "ru", "stt": true,  "tts": true,  "tts_voices": ["female"] },
    { "code": "de", "stt": true,  "tts": true,  "tts_voices": ["female"] },
    { "code": "ja", "stt": true,  "tts": false, "tts_voices": [] }
  ]
}
```

- `stt: false` → bu tilda **gapirib bo'lmaydi** (til tanlash ro'yxatida o'chirilgan holatda
  ko'rsatiladi).
- `tts: false` → tarjima **matn** ko'rinishida beriladi, ovoz chiqarilmaydi (UI faqat matnni
  ko'rsatadi, play tugmasi bo'lmaydi).
- Klient bu ro'yxatni keshlaydi (masalan 24 soat).

### 10.3 Sessiya

Sessiya — bitta jonli suhbat (til juftligi + navbatlar tarixi).

#### `POST api/v1/live/sessions` — sessiya boshlash

**Request:** `{ "my_language": "uz", "other_language": "en" }`

**Response `201`:**

```json
{
  "id": 3301,
  "my_language": "uz",
  "other_language": "en",
  "started_at": "2026-07-20T10:00:00Z",
  "ended_at": null
}
```

- `my_language` standart qiymati — foydalanuvchining **`native_language`**i (1.5-bo'lim).
  Klient uni profilidan oladi (hozir kodda `languageOptions[0]` — qattiq yozilgan, `anylang_mobile.md`).
- Foydalanuvchining tugallanmagan sessiyasi bo'lsa — yangisini yaratish o'rniga **o'shani
  qaytarish** mumkin (`is_new: false`), lekin ekran har ochilganda yangi sessiya boshlash ham
  to'g'ri. Tanlov backendda: tavsiya — **ekran ochilganda yangi sessiya**, chunki har suhbat
  alohida.

#### `PATCH api/v1/live/sessions/{id}` — tillarni o'zgartirish

**Request:** `{ "my_language": "en", "other_language": "uz" }`

- Tillar almashtirilganda (⇄ tugmasi) yoki qo'lda tanlanganda chaqiriladi.
- Eski navbatlar (turns) **o'zgarmaydi** — ular o'z tillari bilan qoladi.

#### `POST api/v1/live/sessions/{id}/end` — sessiyani yakunlash

- Ekran yopilganda/ilova fonga o'tganda chaqiriladi. `ended_at` to'ladi.
- Chaqirilmasa ham xato emas — backend 2 soat harakatsiz sessiyani avtomatik yopadi.

### 10.4 `LiveTurn` obyekti (bitta gap/navbat)

Bu — kelajakdagi "chat kabi ro'yxat" elementining ma'lumoti (play tugmasi + tarjima + asl matn):

```json
{
  "id": 5501,
  "client_turn_id": "9f1c-…-4a2b",
  "session_id": 3301,
  "speaker": "me",

  "source_language": "uz",
  "target_language": "en",

  "text_original":   "Salom, bu qancha turadi?",
  "text_translated": "Hello, how much does this cost?",

  "audio_original_url": "https://cdn.anylang.uz/live/5501-src.m4a",
  "audio_tts_url":      "https://cdn.anylang.uz/live/5501-tts.mp3",
  "audio_duration_seconds": 3,
  "tts_duration_seconds": 3,

  "status": "done",
  "created_at": "2026-07-20T10:00:12Z"
}
```

| Maydon | Izoh |
|---|---|
| `speaker` | `"me"` \| `"other"` — qaysi tugma bosilgani. UI shunga qarab chap/o'ng joylashtiradi |
| `text_original` | STT natijasi — **gapiruvchi tilida** |
| `text_translated` | Tarjima — **qarshi tomon tilida** |
| `audio_original_url` | Yozib olingan asl ovoz (ixtiyoriy — qayta eshitish uchun) |
| `audio_tts_url` | **Sintez qilingan tarjima ovozi** — UI'dagi play tugmasi shuni o'ynatadi. `tts: false` tilda `null` |
| `status` | `done` \| `failed` (10.9) |

> **Chat bilan bir xil tamoyil (8.1):** asl matn ham, tarjima ham **bir yo'la** keladi.
> Foydalanuvchi "asl matnni ko'rish" desa — qo'shimcha so'rov yubormaydi.

### 10.5 `POST api/v1/live/sessions/{id}/turns` — ASOSIY ENDPOINT

Tugma qo'yib yuborilganda yoziб olingan audio shu yerga yuboriladi.

**Request:** `multipart/form-data`

| Maydon | Izoh |
|---|---|
| `audio` | Yozib olingan fayl (10.7) |
| `speaker` | `"me"` \| `"other"` |
| `client_turn_id` | Klient UUID'si — takroriy yuborishdan himoya (8.4 bilan bir xil sabab) |

**Til yo'nalishi avtomatik aniqlanadi** — klient uni yubormaydi:

| `speaker` | `source_language` | `target_language` |
|---|---|---|
| `me` | sessiyaning `my_language` | sessiyaning `other_language` |
| `other` | sessiyaning `other_language` | sessiyaning `my_language` |

**Response `201`:** 10.4-bo'limdagi to'liq `LiveTurn` (STT + tarjima + TTS **tugallangan** holda).

**Backend ichida bajariladigan zanjir:**

```
audio → [STT: source_language] → text_original
      → [Tarjima: source → target] → text_translated
      → [TTS: target_language] → audio_tts_url
```

**Qoidalar:**
- **Nutq topilmasa** (jim yozuv, shovqin): `400 NO_SPEECH_DETECTED` — UI "eshitilmadi, qayta
  urinib ko'ring" deydi. Bo'sh turn saqlanmaydi.
- Obuna tekshiruvi har turn'da (10.1).
- Bir xil `client_turn_id` qayta kelsa — **yangi turn yaratilmaydi**, mavjudi qaytariladi.

### 10.6 `GET api/v1/live/sessions/{id}/turns` — navbatlar tarixi

| Query | Izoh |
|---|---|
| `limit` | Standart 50 |
| `before_id` | Eskiroqlarini yuklash (yuqoriga scroll) |

**Response `200`:** `{ "items": [ ... ], "has_more": false }` — **eskidan yangiga** tartibda.

- Ekran qayta ochilganda yoki ilova qayta ishga tushganda tarixni tiklash uchun.
- `GET api/v1/live/sessions` — o'tgan sessiyalar ro'yxati (kelajakda "suhbatlar tarixi"
  ekrani kerak bo'lsa; hozir UI yo'q).

### 10.7 Audio formatlar va limitlar

| | Qiymat |
|---|---|
| **Kiruvchi (yozib olingan)** | `m4a`/`aac`, `wav`, `ogg`, `mp3`. Tavsiya: **16 kHz, mono** — STT uchun optimal, fayl kichik |
| **Maksimal davomiylik** | **60 soniya** bitta turn uchun (`400 AUDIO_TOO_LONG`) |
| **Maksimal hajm** | 10 MB |
| **Chiquvchi TTS** | `mp3` (yoki `m4a`) — barcha platformalarda o'ynaydi |
| **Saqlash muddati** | Audio fayllar **30 kun** saqlanadi, so'ng o'chiriladi (matnlar qoladi). Bu diskni tejaydi — jonli suhbat audiosi odatda qayta kerak bo'lmaydi |

### 10.8 Kechikish (latency) — eng muhim texnik nuqta

Jonli suhbatda **kechikish hamma narsani hal qiladi.** Ketma-ket bajarilsa:

```
yuklash (0.3s) + STT (0.8s) + tarjima (0.4s) + TTS (1.0s) + yuklab olish (0.3s) ≈ 2.8s
```

**Maqsad: 3 soniyadan kam.** 4–5 soniyadan oshsa suhbat sun'iy tuyuladi.

**Optimallashtirish yo'llari (muhimlik tartibida):**

1. **Xizmatlarni yaqin joyda tanlash** — STT/TTS provayderining eng yaqin regioni.
2. **TTS'ni stream qilish** — audio to'liq tayyor bo'lishini kutmasdan, birinchi baytlardanoq
   qaytarish (FastAPI `StreamingResponse`).
3. **Matnni oldin qaytarish** — `text_original` va `text_translated` tayyor bo'lgach darhol
   yuborish, TTS keyinroq. Buning uchun javob ikki bosqichli bo'ladi (10.8.1).
4. **STT'ni yozish davomida** oqim (streaming) qilib yuborish — eng tez, lekin eng murakkab
   (WebSocket kerak).

#### 10.8.1 Kelajakdagi optimizatsiya (v2) — hozircha shart emas

Agar sinovda 3 soniya chegarasidan oshib ketsa, javobni ikki bosqichga bo'lish tavsiya etiladi:

- `POST /turns` darhol `202` bilan `{ "id": 5501, "status": "processing" }` qaytaradi;
- matn tayyor bo'lganda va TTS tayyor bo'lganda — **WebSocket** orqali
  `live_turn_updated` eventi yuboriladi.

UI bunga tayyor: `jonli_translating` ("Tarjima qilinmoqda…") holati allaqachon dizaynda bor.

> **v1 uchun qaror:** oddiy **sinxron** `POST` yetarli — kod sodda bo'ladi, UI ham shunga mos.
> Streaming'ga o'tish keyin, o'lchangan haqiqiy kechikishga qarab hal qilinadi.

### 10.9 Xatolik kodlari

| `error_code` | HTTP | Qachon |
|---|---|---|
| `SUBSCRIPTION_REQUIRED` | 403 | Basic tarifda Jonli rejim (10.1) |
| `NO_SPEECH_DETECTED` | 400 | Audioda nutq topilmadi |
| `AUDIO_TOO_LONG` | 400 | 60 soniyadan uzun |
| `FILE_TOO_LARGE` | 413 | 10 MB dan katta |
| `UNSUPPORTED_AUDIO_FORMAT` | 400 | Formatlar ro'yxatida yo'q |
| `LANGUAGE_NOT_SUPPORTED` | 400 | Tanlangan tilda STT yoki TTS yo'q (10.2) |
| `SESSION_NOT_FOUND` | 404 | Sessiya yo'q yoki boshqa foydalanuvchiniki |
| `SESSION_ENDED` | 409 | Yakunlangan sessiyaga turn qo'shish |
| `STT_FAILED` / `TRANSLATION_FAILED` / `TTS_FAILED` | 502 | Tashqi xizmat ishlamadi — UI "qayta urinib ko'ring" deydi |

**Qisman muvaffaqiyat qoidasi:** agar STT va tarjima muvaffaqiyatli, lekin **TTS yiqilsa** —
xato **qaytarilmaydi**. Turn `status: "done"`, `audio_tts_url: null` bilan saqlanadi va
matnli tarjima ko'rsatiladi. Foydalanuvchi hech bo'lmasa **o'qiy oladi** — bu butun so'rovni
yo'qotishdan yaxshi.

### 10.10 Jonli rejim uchun FastAPI izohlari

> Butun backendga taalluqli umumiy FastAPI qoidalari — **1.0-bo'limda**. Bu yerda faqat
> shu modulga xos (STT/TTS zanjiri) jihatlar.

- Endpointlar **`async def`** bo'lsin: STT/TTS/tarjima — tarmoq kutishi (I/O), sinxron `def`
  bo'lsa FastAPI uni thread pool'ga tashlaydi va yuk ostida tiqiladi.
- Audio qabul qilish — **`UploadFile`** (fayl diskka stream bo'ladi, xotiraga to'liq
  yuklanmaydi).
- Uchta tashqi chaqiruv ketma-ket bajariladi, lekin **tarjima va TTS'ni birlashtirib**
  bo'lmaydi — TTS tarjima natijasini kutadi. STT'ni esa yuklash bilan **bir vaqtda**
  boshlash mumkin (stream).
- Fayllarni tozalash (30 kunlik muddat, biriktirilmagan yuklamalar) — **`BackgroundTasks`**
  yoki alohida cron/worker (masalan Celery/APScheduler).
- Tashqi xizmatlarga **timeout** qo'yilsin (masalan STT 10s, TTS 10s) — aks holda bitta osilgan
  so'rov butun ishchi jarayonni band qiladi. `httpx.AsyncClient(timeout=...)`.
- Pydantic sxemalari `LiveTurnOut`, `LiveSessionOut` — `/docs` orqali Flutter tarafi kontraktni
  tekshiradi.

### 10.11 Masofaviy (remote) Jonli chaqiruv — qaror

Tarmoq (12) kontakt kartochkasidagi **«Live»** tugmasi mahsulotning asosiy «wow»
funksiyasiga bog'liq.

> ✅ **QAROR:**
> 1. **Mahsulot maqsadi — remote Live (HA).** Ikki foydalanuvchi turli qurilmalardan
>    real vaqtda ovozli tarjima chaqiruvi: ringing/accept, WebRTC (yoki chunked audio),
>    har tomonda STT→MT→TTS, push.
> 2. **To'liq spetsifikatsiya** — alohida «10-bis / Remote Live» bo'limi (14-checklist).
>    Shu yerdagi jadval faqat eskiz.
> 3. **v1 interim (hozir):** «Live» tugmasi **lokal 10.0** oqimini ochadi — peer
>    `native_language` oldindan tanlanadi; audio peer'ga **ketmaydi**. Yangi API yo'q.
>    Remote modul ship qilingach, shu tugma remote chaqiruvga o'tadi (klient feature flag).

#### v1 interim — lokal / device-share (10.0)

1. Tarmoqdan «Live» → Jonli ekrani, suhbatdosh tili peer `native_language`idan.
2. Audio faqat shu qurilmada STT→tarjima→TTS.
3. Yangi API **kerak emas**.

#### Keyingi bosqich — remote eskiz

| Qadam | Texnika |
|---|---|
| Chaqiruv boshlash | `POST /live/calls` `{ "callee_id": 15 }` → `{ "call_id", "status": "ringing" }` |
| Real-time | WS: `call_incoming`, `call_accepted`, `call_declined`, `call_ended` |
| Audio | Har tomon o'z mikrofonini stream qiladi (WebRTC yoki chunked WS) |
| Tarjima | Har tomonda alohida STT→MT→TTS (10.5 zanjiri) |
| Push | Callee offline bo'lsa FCM/APNs |

### 10.12 Aniqlangan UI gap'lar (10-bo'lim)

| UI | Backend | Izoh |
|---|---|---|
| Tarmoqdagi Live tugmasi | 10.11 | v1 lokal; remote — 10-bis |
| Basic da Jonli ochiqligi | 10.1 | UI cheklovi |

---

## 11. Modul: AnyLang raqamlari (Numbers)

Bu modul **butun ilova bo'ylab** ta'sir qiladi: identifikatsiya (4-bo'lim), qidiruv
(7.7, 9.3), obuna (5-bo'lim) va monetizatsiya. Unga mos ekran **hali yo'q** — `anylang_mobile.md` (11-bo'lim).

### 11.0 Asosiy tushuncha

**AnyLang raqami** — har bir foydalanuvchining yagona identifikatori. Bu **haqiqiy telefon
raqam emas**: foydalanuvchining shaxsiy telefon raqami ilovaga umuman aloqador emas (kirish
faqat email bilan — 3-bo'lim). Raqamni ilova taqsimlaydi va sotadi.

| Xususiyat | Qiymat |
|---|---|
| **Uzunlik** | **7 raqam** |
| **Saqlash formati** | Ajratkichsiz string: `"7831111"` |
| **Ko'rsatish formati** | `xxx xx xx` → `783 11 11` (formatlash **klientda**) |
| **Noyoblik** | Butun tizim bo'ylab noyob (unique index) |
| **Berilishi** | Register paytida **avtomatik** — bepul, tasodifiy, oddiy raqam |
| **Almashtirish** | Mumkin — katalogdan yangisini olish orqali (11.5) |
| **Qamrov** | `0000000` – `9999999` (10 million). `0` bilan boshlanadigan raqamlar ham amal qiladi |

> **Qoida:** ilovada raqam bilan bog'liq qayerda joy bo'lsa — hammasida shu `number`
> ishlatiladi: profil subtitle'i (`O'zbekiston · 783 11 11`), biznes profildagi "aloqa"
> qatori, do'st qidirish, chat qidiruv. `phone` va `@username` maydonlari **yo'q**.

### 11.1 Raqam guruhlari (admin belgilaydi)

> Foydalanuvchi so'rovi: *"admin chiroyli nomerlar paketiga turli xil formatda bo'lishi mumkin
> ... nomerlarni turli xil guruhlarga bo'lib chiqiladi va bu guruhlarga umumiy bonuslar
> belgilanadi, muddati ham. Guruhlar yaratish, bonuslar berish — bu admin qiladigan ishlar."*

Raqamlar **guruhlarga (tier)** bo'linadi. Har guruhda: **naqsh (pattern)**, **narx**,
**bonus obuna** va **bonus muddati** bo'ladi. Guruhlarni admin yaratadi va o'zgartiradi —
kod o'zgartirilmaydi.

#### `NumberGroup` obyekti

```json
{
  "id": 4,
  "name": "Platina",
  "patterns": ["AAAAAAA"],
  "price": "499.00",
  "currency": "USD",
  "bonus_plan": "business",
  "bonus_duration_months": 24,
  "priority": 100,
  "is_active": true
}
```

| Maydon | Izoh |
|---|---|
| `patterns` | Naqshlar ro'yxati — 11.2-bo'lim. Raqam shulardan biriga mos kelsa, shu guruhga tegishli |
| `price` | Narx (decimal string). `"0.00"` → bepul guruh |
| `bonus_plan` | `null` \| `"premium"` \| `"business"` — sotib olinganda **avtomatik faollashadigan** tarif (11.4) |
| `bonus_duration_months` | Bonus necha oy amal qiladi. `bonus_plan: null` bo'lsa e'tiborsiz |
| `priority` | Raqam bir nechta guruh naqshiga mos kelsa — **priority yuqori** bo'lgani yutadi (11.2.1) |
| `is_active` | `false` bo'lsa katalogda ko'rinmaydi (yangi sotuvlar to'xtaydi) |

### 11.2 Naqsh (pattern) sintaksisi

Raqam 7 xonali: pozitsiyalar `1234567`, ko'rinishi `123 45 67`.

Naqsh — **7 belgidan** iborat maska:

| Belgi | Ma'nosi |
|---|---|
| `A`–`Z` | Bitta raqam. **Bir xil harf = bir xil raqam**, **turli harf = turli raqam** |
| `*` | Istalgan raqam (cheklovsiz) |

**Misollar:**

| Naqsh | Mos keladi | Mos kelmaydi | Izoh |
|---|---|---|---|
| `AAAAAAA` | `777 77 77` | `777 77 78` | Hammasi bir xil |
| `AAABBCC` | `777 88 99` | `777 88 88` (B=C bo'lib qoldi) | Foydalanuvchi aytgan `xxx yy zz` |
| `AAABBAA` | `777 88 77` | `777 77 77` (A=B) | Foydalanuvchi aytgan `xxx yy xx` |
| `AAAAABB` | `777 77 88` | — | — |
| `ABABABA` | `171 71 71` | — | Navbatma-navbat |
| `AAA****` | `777 12 34` | `123 45 67` | Faqat birinchi 3 tasi bir xil |
| `*******` | Hammasi | — | Standart (oddiy) guruh uchun |

**Maxsus nomli naqshlar** (maskadan tashqari, alohida kalit so'z sifatida):

| Kalit | Ma'nosi | Misol |
|---|---|---|
| `sequential_asc` | Ketma-ket o'sish | `123 45 67` |
| `sequential_desc` | Ketma-ket kamayish | `987 65 43` |
| `palindrome` | Old-orqa bir xil o'qiladi | `123 43 21` |
| `mirror` | Ikki yarmi oyna | `123 32 1` ko'rinishlari |

#### 11.2.1 Bir nechta guruhga moslik

`777 77 77` bir vaqtda `AAAAAAA` ga ham, `AAA****` ga ham, `*******` ga ham mos keladi.
**Qoida:** `priority` eng yuqori bo'lgan **faol** guruh tanlanadi. Shuning uchun standart
(`*******`) guruh eng past `priority` (masalan `0`) bilan yaratiladi.

### 11.3 Boshlang'ich guruhlar va narxlar (taklif)

> Foydalanuvchi so'rovi: *"hozir boshlanishi uchun o'zing nomerlarni narxlab turaver"*.
> Bu — **boshlang'ich taklif**; admin panelidan istalgan vaqtda o'zgartiriladi.

| Guruh | Naqsh(lar) | Narx | Bonus | Muddat | Priority |
|---|---|---|---|---|---|
| **Platina** | `AAAAAAA` | **$499** | Business | 24 oy | 100 |
| **Brilliant** | `AAAAABB`, `AABBBBB` | **$299** | Business | 12 oy | 90 |
| **Oltin** | `AAABBCC`, `AAABBAA` | **$149** | Premium | 12 oy | 80 |
| **Oltin — ketma-ket** | `sequential_asc`, `sequential_desc` | **$129** | Premium | 12 oy | 78 |
| **Kumush** | `AAAABBB`, `palindrome` | **$79** | Premium | 6 oy | 70 |
| **Kumush — juft** | `ABABABA`, `AABBAAB` | **$49** | Premium | 3 oy | 60 |
| **Bronza** | `AAA****`, `****AAA` | **$19** | — | — | 40 |
| **Bronza — oson** | `**AA*AA`, `*AA*AA*` | **$9** | — | — | 30 |
| **Standart** | `*******` | **Bepul** | — | — | 0 |

**Mantiq:** naqsh qanchalik kam uchrasa — shunchalik qimmat. `AAAAAAA` bor-yo'g'i **10 ta**
raqam (0000000…9999999), shuning uchun eng qimmat. `*******` esa — qolgan hammasi, bepul.

> Narx va bonuslar **koddagi konstanta emas** — bazadagi `number_groups` jadvalida turadi.
> Boshlang'ich qiymatlar migratsiya (seed) orqali kiritiladi.

### 11.4 Bonus obuna qanday ishlaydi

Bonusli raqam sotib olinganda — obuna **avtomatik faollashadi**, alohida to'lov kerak emas:

```
Foydalanuvchi "777 88 99" (Oltin, $149) sotib oladi
   ↓
1. Raqam foydalanuvchiga biriktiriladi
2. subscription.plan  → "premium"        (guruhning bonus_plan'i)
   subscription.expires_at → +12 oy       (bonus_duration_months)
   subscription.source → "number_bonus"
```

**Qoidalar:**

| Holat | Nima bo'ladi |
|---|---|
| Foydalanuvchida obuna yo'q (`basic`) | Bonus tarif to'liq muddatga faollashadi |
| Amaldagi obuna **pastroq** (`premium`, bonus `business`) | Tarif **ko'tariladi**, muddat: qolgan muddat + bonus muddati |
| Amaldagi obuna **bir xil yoki yuqori** | Muddat **ustiga qo'shiladi** (uzaytiriladi), tarif pasaymaydi |
| Bonus muddati tugadi | 5.8-qoida bo'yicha `basic`ga tushadi. **Raqam esa foydalanuvchida qoladi** |

- `subscription` obyektiga (5.3) `"source": "purchase" | "number_bonus"` maydoni qo'shiladi —
  bonusdan kelgan obuna `auto_renew: false` bo'ladi (avtomatik to'lov yo'q).
- **Muhim:** raqam **doimiy** — bonus obuna tugasa ham raqam egasida qolaveradi.

### 11.5 Endpointlar

#### `GET api/v1/numbers/catalog` — sotuvdagi raqamlar

| Query | Izoh |
|---|---|
| `search` | Raqam bo'yicha qidirish (prefiks yoki ichidan — masalan `"777"`) |
| `group_id` | Guruh bo'yicha filtr |
| `min_price` / `max_price` | Narx oralig'i |
| `has_bonus` | `true` → faqat bonusli raqamlar |
| `sort` | `price_asc` (standart) \| `price_desc` \| `number_asc` |
| `page`, `limit` | Standart 30 |

**Response `200`:**

```json
{
  "items": [
    {
      "number": "7778899",
      "group": {
        "id": 3, "name": "Oltin",
        "price": "149.00", "currency": "USD",
        "bonus_plan": "premium", "bonus_duration_months": 12
      },
      "is_available": true
    }
  ],
  "page": 1, "limit": 30, "total": 842, "has_more": true
}
```

- Faqat **band bo'lmagan** raqamlar qaytadi.
- 10 million raqamni bazaga oldindan yozish **shart emas** — katalog naqsh bo'yicha
  generatsiya qilinishi mumkin; bazada faqat **band** raqamlar saqlanadi (11.8).

#### `GET api/v1/numbers/groups` — guruhlar ro'yxati

Katalogdagi filtr/tab'lar uchun. `[{ id, name, price, currency, bonus_plan, bonus_duration_months, available_count }]`.

#### `POST api/v1/numbers/random` — bepul tasodifiy raqam olish

**Request:** bo'sh
**Response `200`:** `{ "number": "4862793", "group": { "name": "Standart", "price": "0.00" } }`

- **Standart** (bepul) guruhdan tasodifiy bo'sh raqam biriktiriladi.
- Register paytida **backend o'zi ichkarida** shu mantiqni chaqiradi (11.6).
- Foydalanuvchi joriy raqamidan norozi bo'lsa — bepul yangisini olishi mumkin
  (11.7-cheklovga qarang).

#### `POST api/v1/numbers/purchase` — raqam sotib olish

**Request:** `{ "number": "7778899" }`

**Response `200`:** yangilangan to'liq `User` (yangi `number` va — bonus bo'lsa — yangilangan
`subscription` bilan).

| Xatolik | HTTP | Qachon |
|---|---|---|
| `NUMBER_TAKEN` | 409 | Oradagi vaqtda boshqa odam olib qo'ygan |
| `NUMBER_RESERVED` | 409 | Boshqa foydalanuvchi rezervlab turibdi (11.5.1) |
| `NUMBER_INVALID` | 400 | 7 raqam emas yoki mavjud bo'lmagan naqsh |
| `GROUP_INACTIVE` | 409 | Guruh sotuvdan olingan |
| `PAYMENT_REQUIRED` | 402 | To'lov amalga oshmagan (5.7 — to'lov moduli) |

#### 11.5.1 Rezervatsiya (parallel sotib olishdan himoya)

Ikki foydalanuvchi bir vaqtda bitta raqamni sotib olishga urinishi mumkin.

- `POST api/v1/numbers/reserve` — `{ "number": "7778899" }` → raqam **15 daqiqaga**
  shu foydalanuvchi uchun band qilinadi (`reserved_until`).
- To'lov ekraniga o'tishdan oldin chaqiriladi.
- 15 daqiqada to'lov bo'lmasa — rezerv avtomatik bekor bo'ladi.
- Baza darajasida `number` ustuni **unique** — poyga holatida (race condition) ikkinchi
  yozuv baribir rad etiladi (`409 NUMBER_TAKEN`).

### 11.6 Register paytida avtomatik raqam

**3.3-bo'limdagi register oqimiga qo'shimcha:**

```
POST /auth/register
   ↓
Akkaunt yaratiladi
   ↓
Standart guruhdan tasodifiy bo'sh raqam biriktiriladi  ← YANGI
   ↓
Tasdiqlash kodi emailga yuboriladi
```

- `number` **hech qachon `null` bo'lmaydi** — foydalanuvchi birinchi kunidanoq topiladigan
  bo'ladi.
- Google orqali kirishda (3.7) yangi akkaunt yaratilsa ham xuddi shunday.
- Shu sababli obuna sotib olishda **"raqam bormi?" tekshiruvi kerak emas** — hammada bor.

> **Tasodifiy tanlash haqida (amaliy izoh):** 10 million qamrovdan tasodifiy raqam tanlab,
> band bo'lsa qayta urinish — baza to'lgani sari sekinlashadi. Amaliy yechim: oldindan
> generatsiya qilingan **bo'sh raqamlar navbatini (pool)** ushlab turish (masalan Redis'da
> 10 000 ta tayyor raqam) va fon vazifasi bilan to'ldirib borish.

### 11.7 Raqamni almashtirish

Foydalanuvchi istalgan vaqtda yangi raqam olishi mumkin (bepul tasodifiy yoki katalogdan pullik).

- **Eski raqam darhol katalogga qaytadi** va boshqa odam uni shu zahoti olishi mumkin
  (foydalanuvchi tanlovi bo'yicha — karantin muddati yo'q).
- Eski raqam bilan bog'liq suhbatlar, do'stlar, e'lonlar **buzilmaydi** — ular
  `user_id` ga bog'langan, raqamga emas.
- **Bepul almashtirish cheklovi:** `POST /numbers/random` — **90 kunda 1 marta**
  (`429 NUMBER_CHANGE_COOLDOWN`). Aks holda foydalanuvchi chiroyli raqam chiqquncha
  cheksiz "aylantirib" o'tirishi mumkin. Pullik sotib olishda cheklov **yo'q**.

> ⚠️ **Bilib turish kerak:** eski raqam darhol bo'shagani uchun, kimdir uni olib, avvalgi
> egasining tanishlariga yozishi mumkin (chalkashlik). Agar bu muammo bo'lsa — keyinchalik
> 30–90 kunlik "karantin" qo'shiladi (bir qator o'zgarish).

### 11.8 Ma'lumotlar bazasi bo'yicha izoh

10 million raqamning hammasini jadvalga yozish **shart emas va tavsiya etilmaydi**:

| Yondashuv | Izoh |
|---|---|
| **Tavsiya** | Bazada faqat **band/rezervlangan** raqamlar saqlanadi (`numbers` jadvali: `number` (unique), `user_id`, `group_id`, `purchased_at`, `reserved_until`). Katalog naqsh bo'yicha generatsiya qilinadi va band bo'lganlari chiqarib tashlanadi |
| Muqobil | 10 mln qatorni oldindan yozish — katalog SQL bilan sodda bo'ladi, lekin jadval katta va guruh naqshi o'zgarganda qayta hisoblash kerak |

- `numbers.number` ustuni **UNIQUE** bo'lishi shart — parallel sotib olishdan yagona ishonchli
  himoya (11.5.1).
- Guruh naqshlari o'zgarsa — mavjud egalik qilinган raqamlar **o'zgarmaydi** (`group_id`
  sotib olish paytida yozib qo'yiladi).

---

## 12. Modul: Tarmoq (Network) — B2B kontakt / trust

Ekranlar: `friends` (UI sarlavhasi «Tarmog'im»), `user_card_item`, profile viewers,
networking score bar.

### 12.0 Do'stlar vs Tarmoq — qaror

> ✅ **QAROR:** **alohida qatlamlar, bitta UI tab.**
>
> | Qatlam | Vazifa | API |
> |---|---|---|
> | **9. Do'stlar** | Friendship state machine (`pending` / `accepted` / qayta so'rov) | `/friends/*`, `/users/search` |
> | **12. Tarmoq** | B2B trust, risk, viewers, networking score, filtrlar | `/users/me/profile-viewers`, kengaytirilgan list maydonlari; keyin `/network/search` |
>
> UI pastki tab nomi — **«Tarmoq»** (Do'stlar emas). Yangi friendship jadvali **ochilmaydi** —
> 9.0 qayta ishlatiladi. Tarmoq maydonlari shu bo'limda hujjatlashtiriladi.

**Qamrov:** trust score, AI xavf ogohlantirishi, connections/countries hisoblagichlari,
profile viewers, tarmoq qidiruvi, kontakt kartochka amallari.

### 12.1 Trust Score

`trust_score` — butun son **0–100** (foiz). Business profil uchun hisoblanadi; shaxsiy
hisobda `null` yoki `0`.

#### 12.1.1 Hisoblash formulasi (4.10 uslubida)

Jami 100 ball — omillar ulushi:

| # | Omil | Max ball | Qachon to'liq beriladi |
|---|---|---|---|
| 1 | Profil to'ldirilganlik | 20 | `completeness` (4.10) ≥ 90 → 20; aks holda `completeness * 0.2` |
| 2 | Sertifikatlar | 15 | kamida 1 ta sertifikat (`certificates`) |
| 3 | Tasdiqlangan hujjatlar | 20 | `documents_verified == true` (+ ixtiyoriy `factory_verified` +5 ichida) |
| 4 | `verified_badge` | 10 | admin bergan belgi |
| 5 | Reyting | 15 | `rating` 0–5 → `(rating/5)*15`; sharh yo'q → 0 |
| 6 | Muvaffaqiyatli bitimlar | 10 | `successful_deals` (≥10 → 10, liniya) |
| 7 | Akkaunt yoshi | 5 | ≥ 180 kun → 5; ≥ 30 kun → 3; aks holda 1 |
| 8 | Shikoyatlar jarimasi | −40 gacha | har `complaints_count` uchun −8 (min 0 ga qisqaradi) |

**Qoidalar:**
- Natija `max(0, min(100, round(sum)))`.
- Ro'yxat (friends list) uchun **engil** variant (sync, DB so'rovsiz) ruxsat — to'liq variant
  profil (`4.11` / `trust_score` obyekti) da breakdown bilan.
- Public javobda qisqa shakl: `{ "score": 72, "level": "medium" }` yoki faqat `trust: 72`.

`level` (ixtiyoriy): `low` (<40) / `medium` (40–69) / `high` (≥70).

### 12.2 AI xavf ogohlantirishi (scam / risk)

Boshqa foydalanuvchi profilida ko'rinadigan obyekt:

```json
{
  "risk_level": "high",
  "risk_score": 78,
  "show_warning": true,
  "message": "Bu kompaniyada xavf yuqori.",
  "reasons": [
    { "key": "NEW_ACCOUNT", "label": "Yangi hisob" },
    { "key": "UNVERIFIED_DOCUMENTS", "label": "Tasdiqlanmagan hujjatlar" }
  ],
  "generated_by": "rules"
}
```

#### 12.2.1 `risk_level`

| Kod | Ma'nosi |
|---|---|
| `none` | Ogohlantirish yo'q |
| `low` | Past |
| `medium` | O'rtacha — UI sariq |
| `high` | Yuqori / scammer — UI qizil |

#### 12.2.2 `reasons` — enum va til xaritasi (4.5.1 uslubida)

| Kod | uz_UZ | ru_RU | us_US |
|---|---|---|---|
| `NEW_ACCOUNT` | Yangi hisob | Новый аккаунт | New account |
| `UNVERIFIED_DOCUMENTS` | Noto'g'ri yoki tasdiqlanmagan hujjatlar | Непроверенные документы | Unverified documents |
| `MANY_BLOCKS` | Ko'p foydalanuvchi bloklagan | Много блокировок | Many blocks |
| `SUSPICIOUS_ACTIVITY` | Shubhali harakatlar | Подозрительная активность | Suspicious activity |
| `HIGH_COMPLAINTS` | Ko'p shikoyat | Много жалоб | High complaints |
| `LOW_TRUST` | Past trust score | Низкий trust score | Low trust score |

#### 12.2.3 Yondashuv — qaror (A + B)

| Yondashuv | Qanday ishlaydi | `generated_by` |
|---|---|---|
| **A) Qoidalar dvijogi** (majburiy) | Akkaunt yoshi, sertifikat, complaints, trust, shubhali faollik → `risk_score` / `risk_level` / `reasons` | `rules` |
| **B) LLM** (ixtiyoriy) | Ball va `reasons` o'zgarmaydi; faqat `message` matni OpenAI bilan boyitiladi (kalit yo'q → A matni) | `openai` |

> ✅ **QAROR:** production — **A majburiy + B ixtiyoriy**. Score hech qachon faqat LLM dan
> kelmaydi (deterministik, auditable). `OPENAI_API_KEY` bo'lmasa to'liq A ishlaydi.

**Qayerda qaytadi:** `GET /users/{id}` (4.11) ichida `scam_risk` / `risk` maydoni;
tarmoq kartochkasida qisqa: `is_scammer`, `risk_level` (12.7).

### 12.3 Connections / Countries hisoblagichlari

| Maydon | Ma'nosi |
|---|---|
| `connections_count` | Accepted aloqalar (friendship) soni |
| `countries_count` | Aloqalar + o'z `export_countries` / `country` bo'yicha **turli** davlatlar soni |

**Qayerda:**
- `GET /friends` javobidagi `networking: { connections, countries, trust }` (mavjud
  `NetworkingScoreOut` bilan mos).
- Profil / tarmoq header («🤝 5 Connections», «🌍 1 Countries», «⭐ Trust 56»).

### 12.4 Profile viewers — «Kim sizni qidirdi»

#### Tracking

`GET /users/{id}` (4.11) chaqirilganda (autentifikatsiyalangan ko'ruvchi, o'zini emas):
backend `profile_views` jadvaliga yozadi: `(viewer_id, viewed_id, viewed_at)`.
Bir kun ichida bir xil juftlik — **upsert** (spam oldini olish).

#### `GET api/v1/users/me/profile-viewers`

**Query:** `page`, `limit` (standart 20).

> Alias (ixtiyoriy keyin): `GET /network/viewers` — xuddi shu handler.

**Response `200` (Premium/Business):**

```json
{
  "items": [
    {
      "user_id": 88,
      "full_name": "Nordic Imports",
      "avatar_url": "...",
      "country": "FI",
      "is_business": true,
      "viewed_at": "2026-07-25T18:02:00Z"
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 14,
  "has_more": false,
  "locked": false
}
```

**Response `200` (Basic — locked):**

```json
{
  "items": [],
  "total": 14,
  "locked": true,
  "upgrade_plan": "premium"
}
```

> ✅ **QAROR (viewers tarif):** **LinkedIn uslubi — Premium / Business.** Basic da faqat
> `total` + `locked: true` (kimligi yashirin). Tracking hamma autentifikatsiyalangan
> ko'ruvchi uchun yoziladi; **ko'rish huquqi** tarifga bog'liq. `FEATURE_LOCKED` / `locked`
> maydoni — klient upgrade CTA uchun.

**Xatoliklar:** `401 UNAUTHORIZED`.

### 12.5 `GET api/v1/network/search` — tarmoq qidiruvi

9.3 (`GET /users/search`) ga o'xshash, lekin B2B filtrlari bilan.

| Query | Izoh |
|---|---|
| `q` | Ism / kompaniya / AnyLang raqam |
| `country` | ISO 3166-1 alpha-2 |
| `business_role` | 4.5.1 enum |
| `category` | 6.12 mahsulot kategoriyasi (sotuvchining e'lonlari orqali) |
| `verified` | `true` → `verified_badge == true` |
| `online` | `true` → hozir onlayn |
| `page`, `limit` | Standart pagination |

**Response `200`:**

```json
{
  "items": [
    {
      "id": 42,
      "full_name": "Anadolu Craft Co.",
      "company_name": "Anadolu Craft Co.",
      "number": "7831111",
      "avatar_url": "...",
      "is_online": false,
      "last_seen_at": "2026-07-25T10:00:00Z",
      "country": "TR",
      "is_business": true,
      "verified_badge": true,
      "business_role": "manufacturer",
      "rating": 4.8,
      "reviews_count": 24,
      "trust": 72,
      "risk_level": "none",
      "is_scammer": false,
      "products_count": 8,
      "countries_count": 3,
      "friendship_status": "none"
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 1,
  "has_more": false
}
```

### 12.6 Kontakt kartochkadagi 4 tugma

| Tugma | Backend | Izoh |
|---|---|---|
| Chat | `POST /chats` (7.5) | Mavjud |
| Live | → **10.11** (v1 lokal; remote — 10-bis) | Feature flag |
| Mahsulot | `GET /users/{id}/products` (6.10) | Mavjud |
| Profil | `GET /users/{id}` (4.11) | + risk/trust |

### 12.7 Asosiy ro'yxat — `GET api/v1/friends` kengaytmasi

9.2 javobidagi har bir `Friend` ga qo'shimcha maydonlar (breaking emas — ixtiyoriy):

| Maydon | Tip |
|---|---|
| `rating` | float \| null |
| `reviews_count` | int |
| `trust` | int \| null |
| `risk_level` | string |
| `is_scammer` | bool |
| `products_count` | int |
| `countries_count` | int |
| `keywords` | string[] |
| `product_categories` | string[] |

**Response qo'shimcha root:**

```json
{
  "networking": {
    "connections": 5,
    "countries": 1,
    "trust": 56
  },
  "pending_incoming_count": 2
}
```

### 12.8 Backenddan KELMAYDIGAN narsalar (klient hisoblaydi)

| Narsa | Nega klientda |
|---|---|
| «Online» / «Kecha» / «5 daqiqa oldin» | 7.8 + 7.10 — til va vaqt zonasi |
| Davlat nomi + bayroq emoji | Backend faqat `country` kodi; nom lokalizatsiya |
| «Kompaniya» / «Foydalanuvchi» chip matni | `is_business` + `business_role` dan klient |
| Reyting yulduzchasini chizish | `rating` xom float |
| Scammer qizil UI | `is_scammer` / `risk_level` — rang klientda |

### 12.9 Xatolik kodlari (Tarmoq)

| `error_code` | HTTP | Qachon |
|---|---|---|
| `UNAUTHORIZED` | 401 | Token yo'q |
| `VALIDATION_ERROR` | 400 | Noto'g'ri filtr |
| `USER_NOT_FOUND` | 404 | Qidiruv / profil |
| `FEATURE_LOCKED` | 403 | Viewers Basic da to'liq ochilmasa (`locked: true` ham mumkin) |

### 12.10 Aniqlangan UI gap'lar (12-bo'lim)

| UI | Backend | Izoh |
|---|---|---|
| Trust / Connections / Countries header | 12.3 / 12.7 | |
| Karta reyting + scammer qizil | 12.2 / 12.7 | |
| Filtrlar: Davlat / Soha / Mahsulot / Verified | 12.5 | |
| Profile viewers horizontal | 12.4 | Premium/Business |
| Live tugmasi | 10.11 | v1 lokal → remote |
| Do'stlar vs Tarmoq | 12.0 | Bitta UI, 9+12 qatlam |

---

## 13. Modul: Guruh chatlar (Group chats)

8-bo'lim faqat **1-1** chatni qamraydi. Skrinshotlarda «Yangi guruh» va guruh suhbati bor —
shu modul.

### 13.0 Qamrov

- Guruh yaratish, a'zolar, rollar, sozlamalar
- Guruh xabarlari (8.2 ga o'xshash + `sender`)
- WebSocket eventlari
- Tarjima (ko'p tilli fan-out)

**Kirish nuqtasi:** suhbatlar ro'yxatida `chat.type == "group"` (7.2 ga maydon qo'shiladi).

### 13.1 `POST api/v1/groups` — guruh yaratish

**Request:**

```json
{
  "name": "Tekstil hamkorlar",
  "avatar_id": null,
  "member_ids": [15, 22, 31]
}
```

**Response `201`:**

```json
{
  "id": 9001,
  "type": "group",
  "name": "Tekstil hamkorlar",
  "avatar_url": null,
  "owner_id": 1,
  "members_count": 4,
  "created_at": "2026-07-26T09:00:00Z"
}
```

**Qoidalar:**
- Yaratuvchi avtomatik `owner` va a'zo.
- `member_ids` — mavjud userlar; o'zini qayta qo'shish e'tiborsiz.
- Minimal a'zolar: yaratuvchi + kamida 1 (yoki 2 — mahsulot qarori: **kamida 1**).
- Max a'zolar (tavsiya): 200.

**Xatoliklar:** `400 VALIDATION_ERROR`, `404 USER_NOT_FOUND`, `403 USER_BLOCKED`.

### 13.2 Rollar va ruxsatlar

| Amal | owner | admin | member |
|---|---|---|---|
| Xabar yozish | ✓ | ✓ | ✓ |
| Guruh nomini/rasmini o'zgartirish | ✓ | ✓ | ✗ |
| A'zo qo'shish | ✓ | ✓ | ✗ |
| A'zoni chiqarish | ✓ | ✓ (owner/admin chiqara olmaydi) | ✗ |
| Admin tayinlash / olish | ✓ | ✗ | ✗ |
| Tark etish (leave) | ✓* | ✓ | ✓ |
| Guruhni o'chirish (delete) | ✓ | ✗ | ✗ |

\* Owner leave qilsa — avval boshqa a'zoga ownership o'tkazilishi yoki guruh o'chirilishi
kerak (qoida: **ownership majburiy o'tkazish**, aks holda `400 OWNER_MUST_TRANSFER`).

### 13.3 Guruh xabari

8.2 `Message` ga qo'shimcha:

```json
{
  "id": 12001,
  "chat_id": 9001,
  "client_message_id": "…",
  "type": "text",
  "is_outgoing": false,
  "sender": {
    "id": 15,
    "full_name": "Anna Müller",
    "avatar_url": "…"
  },
  "text_original": "Hallo!",
  "text_translated": "Salom!",
  "translated_language": "uz",
  "is_translated": true,
  "created_at": "2026-07-26T09:05:00Z",
  "read_count": 2,
  "members_count": 4
}
```

**Qoida:** 1-1 da `is_outgoing` yetarli edi; guruhda **har doim** `sender` to'ldiriladi
(o'z xabarida ham).

Xabar yuborish: `POST /chats/{chat_id}/messages` (8.4) — guruh `chat_id` bilan ishlaydi.

### 13.4 Ko'p tomonlama o'qilganlik

> ✅ **QAROR:** guruhda default — **sodda hisoblagich.**
>
> | Variant | Schema | Holat |
> |---|---|---|
> | **Sodda (default)** | `read_count` + `members_count` — UI «2/4 o'qidi» | v1 |
> | To'liq (opt-in keyin) | `read_by: [{ "user_id", "read_at" }]` — faqat kichik guruh yoki `?expand=read_by` | keyin |
>
> Katta guruhlarda to'liq ro'yxat og'ir — shuning uchun v1 da count yetarli.

`POST /chats/{id}/read` (7.6 / 8.7) guruhda ham ishlaydi — o'qilgan `message_ids` uchun
hisoblagich oshadi.

### 13.5 Guruh sozlamalari — endpointlar

| Method | Path | Izoh |
|---|---|---|
| `GET` | `/groups/{id}` | Nom, avatar, a'zolar, mening rol |
| `PATCH` | `/groups/{id}` | `{ "name"?, "avatar_id"? }` — owner/admin |
| `POST` | `/groups/{id}/members` | `{ "user_ids": [...] }` |
| `DELETE` | `/groups/{id}/members/{user_id}` | Kick |
| `POST` | `/groups/{id}/leave` | Tark etish |
| `DELETE` | `/groups/{id}` | Faqat owner — soft delete |

**`GET /groups/{id}` response namunasi:**

```json
{
  "id": 9001,
  "name": "Tekstil hamkorlar",
  "avatar_url": null,
  "owner_id": 1,
  "my_role": "owner",
  "members": [
    { "user_id": 1, "full_name": "Men", "role": "owner", "avatar_url": "…" },
    { "user_id": 15, "full_name": "Anna Müller", "role": "member", "avatar_url": "…" }
  ],
  "members_count": 2
}
```

### 13.6 WebSocket eventlari (8.9 / 9.5 uslubida)

| Event | Qachon | `data` |
|---|---|---|
| `group_message` | Yangi guruh xabari | `Message` (13.3) + `chat_id` |
| `group_member_added` | A'zo qo'shildi | `chat_id`, `members[]` |
| `group_member_removed` | Kick / leave | `chat_id`, `user_id` |
| `group_updated` | Nom/avatar | `chat_id`, `name`, `avatar_url` |
| `group_deleted` | Owner o'chirdi | `chat_id` |

Format: `{ "type": "...", "data": { ... } }`. Redis pub/sub (1.0 / 7.9).

### 13.7 Guruhda tarjima

8.1 «ko'ruvchiga qarab tarjima» guruhda murakkablashadi: a'zolarning `native_language`
har xil.

> ✅ **QAROR:** **lazy per-viewer + cache** (8.1.1).
>
> | Strategiya | Holat |
> |---|---|
> | **Lazy per-viewer** | Tarjima so'rov / WS yetkazishda kerakli tilga; cache | **v1 default** |
> | Eager fan-out | Barcha a'zo tillariga oldindan | **Yo'q** (qimmat) |
>
> Background job faqat faol (oxirgi N kun) tillar uchun ixtiyoriy prewarm — majburiy emas.

### 13.8 Xatolik kodlari (Guruh)

| `error_code` | HTTP | Qachon |
|---|---|---|
| `GROUP_NOT_FOUND` | 404 | Yo'q yoki a'zo emas |
| `NOT_GROUP_ADMIN` | 403 | Ruxsat yo'q |
| `OWNER_MUST_TRANSFER` | 400 | Owner leave qilmoqchi |
| `MEMBERS_LIMIT` | 400 | Max a'zolar |
| `VALIDATION_ERROR` | 400 | Bo'sh nom va h.k. |

### 13.9 Backenddan KELMAYDIGAN narsalar

| Narsa | Klient |
|---|---|
| «N kishi o'qidi» matni | `read_count` / `members_count` dan lokalizatsiya |
| Sender ismi rangi / avatar gradient | `sender.id` dan |
| Vaqt formatlash | 7.10 |

### 13.10 Aniqlangan UI gap'lar (13-bo'lim)

| UI | Backend | Izoh |
|---|---|---|
| Yangi guruh | 13.1 | |
| Guruh chat bubblida ism | 13.3 `sender` | |
| Guruh sozlamalari | 13.5 | |
| Kim o'qidi | 13.4 | `read_count` (default) |
| Ko'p tilli tarjima | 13.7 | Lazy + cache |

---

## 14. Keyingi TZ bosqichlari (hali yozilmagan / yangilangan)

Quyidagilar navbat bilan, mavjud ekranlar asosida alohida bo'lim sifatida qo'shib boriladi:

- [x] ~~**Auth**~~ — 2–3-bo'lim (yozildi)
- [x] ~~**Profil / Hisob turlari**~~ — 4-bo'lim (yozildi)
- [x] ~~**Profil qo'shimchalari**~~ — 4.15–4.21 (yutuqlar, AI match/insights, factory video, analytics, certificates breaking)
- [x] ~~**Tariflar / Obuna**~~ — 5-bo'lim (yozildi; to'lov integratsiyasi keyin)
- [x] ~~**Bozor**~~ — 6-bo'lim (yozildi)
- [x] ~~**Bozor qo'shimchalari**~~ — 6.19–6.22 (recommended, map, banners, Durable = capability)
- [x] ~~**Xabarlar — suhbatlar ro'yxati + chat search**~~ — 7-bo'lim (yozildi)
- [x] ~~**Chat (suhbat ichi)**~~ — 8-bo'lim (yozildi; asl+tarjima bir yo'la keladi)
- [x] ~~**Chat attachment + Smart Reply**~~ — 8.3 / 8.11 (invoice qo'lda; offer/catalog/business_card)
- [x] ~~**Do'stlar**~~ — 9-bo'lim (yozildi)
- [x] ~~**Tarmoq (Network)**~~ — 12-bo'lim (yozildi; qarorlar yakunlandi)
- [x] ~~**Guruh chatlar**~~ — 13-bo'lim (yozildi; read=count, tarjima=lazy)
- [x] ~~**Jonli rejim**~~ — 10-bo'lim (yozildi; STT→tarjima→TTS to'liq backendda)
- [ ] **Remote Jonli chaqiruv (10-bis)** — 10.11 QAROR: HA; to'liq spets + WebRTC/push keyingi bosqich
- [x] ~~**AnyLang raqamlari**~~ — 11-bo'lim (yozildi; guruhlar, katalog, bonus obuna)
- [ ] **Sozlamalar / Maxfiylik** — `settings` (bildirishnoma sozlamalari, profil ko'rinishi, bloklangan foydalanuvchilar, parol o'zgartirish, email o'zgartirish)
- [ ] **To'lov** — Click/Paddle credentials + Paddle price_id lar productionda to'ldirish; Flutter checkout WebView ulash (5.7)
- [ ] **Invoice avto-PDF** — ixtiyoriy `POST /chats/{id}/invoices` (8.3.3; v1 qo'lda yetarli)
- [ ] **Admin** — **raqam guruhlarini yaratish/bonus belgilash (11.1)**, `verified_badge` berish, hisoblarni bloklash (`is_active`), **marketplace bannerlar CRUD (6.21)**
- [ ] Push-bildirishnomalar (umumiy infratuzilma; remote Live chaqiruv uchun ham)
