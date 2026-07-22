# AnyLang — Mobil (Flutter) tasklar ro'yxati

**Bu fayl — Flutter tomonidagi ishlar.** Backend kontrakti alohida hujjatda:
[`anylang_backend.md`](anylang_backend.md).

Har bir task backend TZ'ning tegishli bo'limiga havola qiladi (masalan **BE 7.7** =
`anylang_backend.md` ning 7.7-bo'limi). Backend tayyor bo'lgach shu ro'yxat bo'yicha
ilova ulanadi.

> **Eslatma:** ilovaning hozirgi holati — **to'liq ishlaydigan dizayn maketi**. Barcha ekranlar
> qurilgan va navigatsiya ishlaydi, lekin ma'lumotlar **mock** (qattiq yozilgan) va hech qanday
> tarmoq so'rovi yuborilmaydi. Quyidagi tasklar — shu maketni tirik ilovaga aylantirish.

---

## 0. Loyiha qoidalari

Barcha ishlar [`CLAUDE.md`](CLAUDE.md) dagi arxitektura qoidalariga muvofiq bajariladi:
Screen/Content/State/Action tuzilishi, `.dp`/`.sp` o'lchamlar, `context.appColors`,
lokalizatsiya (`'kalit'.tr`), `ui/items/` da item widgetlar va h.k.

---

## 1. Paketlar (`pubspec.yaml`) — hozircha yo'q, qo'shilishi kerak

| Paket | Nima uchun | Qayerda | BE |
|---|---|---|---|
| `record` (yoki muqobil) | **Ovoz yozish** — chatdagi ovozli xabar va Jonli rejim | `chat`, `jonli` | 8.5, 10.5 |
| `just_audio` (yoki muqobil) | **Audio ijro** — ovozli xabar va TTS javobini o'ynatish | `chat`, `jonli` | 8.3, 10.4 |
| `google_sign_in` | Google orqali kirish | `login` | 3.7 |
| `flutter_contacts` | Chatga kontakt biriktirish | `chat` | 8.3 |
| `visibility_detector` | Xabar ko'rinishini kuzatish (o'qilganlik) | `chat` | 8.7 |
| `uuid` | `client_message_id` / `client_turn_id` generatsiya | `chat`, `jonli` | 8.4, 10.5 |

**Allaqachon bor va ishlatiladi:** `dio`, `hive`, `web_socket_channel`, `image_picker`,
`geolocator`, `permission_handler`, `flutter_svg`, `get`.

---

## 2. Umumiy (cross-cutting) tasklar

### 2.1 Base URL
- [ ] `lib/data/core/buildNetwork/api_config.dart` → `kBaseUrl` hozir `'BASE_URL'` placeholder.
      Haqiqiy manzil bilan almashtiriladi. **BE 1.1**

### 2.2 Xatoliklarni ko'rsatish
- [ ] `network_client.dart` hozir faqat HTTP status/timeout turiga qarab umumiy xabar
      ko'rsatadi. Backend javobidagi `{"message", "error_code"}` o'qiladigan qilinadi va
      foydalanuvchiga aniq xabar ko'rsatiladi. **BE 1.3**

### 2.3 Ikki xil til modeli — MUHIM o'zgarish
Backend ikkita alohida til maydonini kutadi (**BE 1.5**):
- `app_language` — interfeys tili (`uz_UZ` / `ru_RU` / `us_US`)
- `native_language` — **ona tili**, ISO 639-1 (`uz`, `de`, `ja`, ...) → **xabarlar shunga
  tarjima qilinadi**

- [ ] `LanguageOption` (`select_language_option.dart`) ga **`langCode`** (ISO 639-1) maydoni
      qo'shiladi — hozir faqat `localeCode` (`uz_UZ`) bor.
- [ ] `select_language_screen.dart` tanlovda **ikkala** qiymatni yuboradigan qilinadi.
      Hozir faqat `localeCode` saqlanadi.
- [ ] Til tanlashda `localeCode == null` bo'lgan tillar (`tr`, `es`, `de`, `fr`) ham
      `native_language` sifatida yuboriladi — interfeys tili esa o'zgarmaydi.

### 2.4 AnyLang raqami (7 xonali) — **BE 11**
- [ ] `formatters/` ga `formatAnylangNumber()` qo'shiladi: `"7831111"` → `"783 11 11"`.
- [ ] Kiritish uchun maska (`phone_input_formatter.dart` ga o'xshash) — `xxx xx xx`.
- [ ] Profildagi `@username` **olib tashlanadi**, o'rniga raqam ko'rsatiladi:
      `O'zbekiston · 783 11 11` (`profile_account.dart` dagi `username` → `number`).
- [ ] Biznes public profilidagi "Telefon" qatorida haqiqiy telefon emas, **AnyLang raqami**
      ko'rsatiladi (dizayndagi `+90 212 555 04 18` o'rniga).
- [ ] `ProfileModel` (`domain/models/profile_model.dart`) yangi `User` sxemasiga moslanadi:
      `region_id`/`district_id`/`phone` **olib tashlanadi**, `number`, `native_language`,
      `app_language`, `subscription`, `business` qo'shiladi. **BE 4.1**

### 2.5 Eskirgan (legacy) kodni tozalash
- [ ] `data/network/auth_repository.dart` — telefon + SMS OTP asosida yozilgan (eski "Navbat"
      loyihasidan). **Email + parol** oqimiga qayta yoziladi. **BE 3**
- [ ] `ProfileRepository.getRegions()`, `local_regions_repository.dart`, `database_service.dart`
      dagi `regions`/`districts` jadvallari — **bekor qilindi**, o'chiriladi. **BE 0.1**
- [ ] `domain/models/region_model.dart`, `district_model.dart` — o'chiriladi.

### 2.6 Sahifalash (pagination) — umumiy
Barcha ro'yxatlar hozir bir martada to'liq yuklanadi. `page`/`limit` bilan pastga scrollda
yuklash qo'shiladi: mahsulotlar, suhbatlar, do'stlar, xabarlar tarixi.

### 2.7 Server tomon qidiruvi — umumiy
Barcha qidiruvlar hozir **klient tomonda** filtrlaydi. Server so'roviga (debounce ~300ms)
o'tkaziladi: mahsulotlar, suhbatlar, do'stlar, foydalanuvchilar.

---

## 3. Auth (kirish) — BE 3

- [ ] `login_screen.dart`, `register_screen.dart`, `verify_screen.dart` — barcha `TODO`
      so'rovlarga ulanadi.
- [ ] **Login javobidagi `403 ACCOUNT_NOT_VERIFIED`** holati: foydalanuvchi `email` payload
      bilan Verify ekraniga yo'naltiriladi (backend kodni avtomatik qayta yuboradi). **BE 3.6**
- [ ] `google_sign_in` paketi ulanadi, `id_token` backendga yuboriladi. **BE 3.7**
- [ ] **"Parolni unutdim"** oqimi uchun ekranlar hali yo'q — quriladi:
      (1) email kiritish → (2) kod + yangi parol. **BE 3.10, 3.11**
- [ ] `country_picker_bottom_sheet.dart` hozir faqat ko'rinadigan nomni qaytaradi
      (`"O'zbekiston"`). **ISO alpha-2 kod** (`UZ`) bilan juftlik saqlanadigan qilinadi. **BE 3.14**
- [ ] **Ilova ochilganda avtomatik kirish:** Hive'dagi `refreshToken` yaroqli bo'lsa
      `api/v1/auth/refresh` chaqirilib to'g'ridan-to'g'ri Main ekranga o'tiladi. Hozir
      `main.dart` doim Select Language'dan boshlaydi. **BE 3.1-D**
- [ ] `refresh` `401` qaytarsa — Login ekraniga qaytarish. **BE 3.9**
- [ ] Settings'dagi "Hisobdan chiqish" → `POST /auth/logout` chaqiradi. **BE 3.8**

---

## 4. Profil va hisob turlari — BE 4

- [ ] `profile_screen.dart` `initState` → `GET /users/me`. Hozir `kMockPersonalAccount`.
- [ ] Profil shakli `subscription.plan` ga qarab o'zgaradi (free / premium / business).
      Hozir `isBusiness` mock bool. **BE 4.0**
- [ ] `profile_edit_screen.dart` → `PATCH /users/me` + avatar yuklash. Hozir TODO.
- [ ] **Email maydoni read-only qilinadi** — email o'zgartirish tasdiqlashsiz xavfli, alohida
      oqim keyingi bosqichda. **BE 4.3**
- [ ] `edit_business_info_screen.dart` → `GET`/`PATCH /users/me/business`, logotip va zavod
      rasmlari alohida yuklanadi. Hozir hammasi mock.
- [ ] `kBusinessRoles` (`edit_business_info_content.dart`) hozir faqat o'zbekcha matnlar —
      **kod↔tarjima juftligi**ga o'tkaziladi (`manufacturer` va h.k.). **BE 4.5.1**
- [ ] Sertifikat qo'shish dialogi yo'q (`AddCertificateRequested` → TODO) — quriladi.
- [ ] Zavod rasmini **o'chirish** tugmasi yo'q — qo'shiladi (`DELETE .../factory-images/{id}`).
- [ ] **`founded_year` maydoni yo'q** — biznes tahrirlash ekraniga "tashkil etilgan yil"
      qo'shiladi (public profildagi "12 yildan beri" shundan hisoblanadi). **BE 4.5**
- [ ] `user_profile_screen.dart` → `GET /users/{id}`. Hozir payload orqali mock keladi.
- [ ] Statistika (`3.4k`) formatlash klientda: backend xom son (`3400`) yuboradi. **BE 4.12**

---

## 5. Tariflar / Obuna — BE 5

- [ ] `subscription_screen.dart` `initState` → `GET /subscription/plans`. Hozir
      `kMockSubscriptionPlans`.
- [ ] "JORIY TARIF" belgisi backenddan emas — `plan.code == user.subscription.plan`
      solishtiruvidan chiqadi. **BE 5.2**
- [ ] `SelectPlan` → `POST /subscription/subscribe` (to'lov oqimi bilan birga). Hozir TODO.
- [ ] Obuna bekor qilish UI yo'q — qo'shiladi (`POST /subscription/cancel`).

---

## 6. Bozor (mahsulotlar) — BE 6

- [ ] `products_screen.dart` → `GET /products` va `GET /products/top`. Hozir mock.
- [ ] **Atributlar** (`Material: 100% jun`) — S11'da chip sifatida ko'rsatiladi, lekin S18'da
      **kiritish maydoni yo'q** (kodda `_attributes` hardcoded). "Atribut qo'shish"
      (nom+qiymat) bloki quriladi. **BE 6.2**
- [ ] `add_product_screen.dart` → rasm yuklash (`POST /products/images`) + `POST /products`.
      Hozir mock gradient qo'shadi.
- [ ] **Sevimlilar (♥)** — tugma faqat lokal holatni o'zgartiradi. `POST`/`DELETE
      /products/{id}/favorite` ga ulanadi. Kelajakda "Sevimlilar" ekrani. **BE 6.11**
- [ ] **"Bog'lanish"** — `onTap: () {}` bo'sh. `POST /chats` → chat ekraniga. **BE 6.17**
- [ ] **"Barchasi"** (Top mahsulotlar) — oddiy `Text`, bosilmaydi. Bosiladigan qilinadi.
- [ ] **E'lonni tahrirlash ekrani yo'q** (`OpenOwnListing` → TODO). S18 ekrani **tahrirlash
      rejimi**ni qo'llab-quvvatlaydigan qilinadi (`payload` sifatida `product_id`) — kodda
      allaqachon TODO bor. **BE 6.8**
- [ ] Kategoriyalar (`kProductCategories`) — kod↔tarjima juftligiga o'tkaziladi. **BE 6.12**
- [ ] Narx formatlash klientda: backend `"24.00"` + `"USD"` yuboradi, `$24.00` klientda
      yig'iladi. Ko'rishlar (`1.2k`) ham. **BE 6.1**

---

## 7. Xabarlar (suhbatlar ro'yxati) — BE 7

- [ ] `messages_screen.dart` → `GET /chats`. Hozir `kMockConversations`.
- [ ] **Qidiruv** — hozir klient tomonda, faqat ism bo'yicha, bitta ro'yxat.
      `GET /chats/search` ga o'tkaziladi va UI **ikki bo'limli** qilinadi:
      "Suhbatlar" + "Boshqa foydalanuvchilar". **BE 7.7**
- [ ] Qidiruv turi backendda aniqlanadi (ism → faqat suhbatlar, raqam → ikkala ro'yxat).
      Klient hech narsa yubormaydi, faqat javobdagi ikki ro'yxatni chizadi. **BE 7.7.0**
- [ ] **"+" tugmasi** (`NewConversation` → TODO) — foydalanuvchi tanlash/qidirish orqali
      `POST /chats`. **BE 7.5**
- [ ] `highlighted` (lime fon) backenddan kelmaydi — `unread_count > 0` dan hisoblanadi.
- [ ] Oxirgi xabar ko'rinishi (`"Ovozli xabar · 0:12"`) **backenddan tayyor kelmaydi** —
      `type` + `meta` dan lokalizatsiya kalitlari bilan yig'iladi. **BE 7.3**
- [ ] Vaqt (`14:32` / `Kecha` / `Yak`) ISO'dan klientda formatlanadi. **BE 7.10**
- [ ] Onlayn nuqtasi — `presence` WS eventiga ulanadi. **BE 7.8**

### 7.1 ⚠️ WebSocket — xavfsizlik tuzatishi (MUHIM)
`socket_service.dart:10` hozir `ws://84.32.100.42/ws/{userId}` manziliga ulanadi —
**autentifikatsiya yo'q**, faqat URL'dagi `userId`. Istalgan odam boshqa birovning `userId`sini
qo'yib uning xabarlarini o'qiy oladi. Qolaversa `ws://` — shifrlanmagan.

- [ ] `wss://` (TLS) ga o'tkaziladi.
- [ ] Ulanish **access token** bilan autentifikatsiya qilinadi (`?token=...`), `userId`
      URL'dan olib tashlanadi. **BE 7.9**

---

## 8. Chat (suhbat ichi) — BE 8

- [ ] `chat_screen.dart` → `GET /chats/{id}/messages` (sahifalash bilan) va
      `POST /chats/{id}/messages`. Hozir `_mockThread()`.
- [ ] **Asl matnni ko'rsatish** — 3c menyusida band bor, lekin `MessageMenuAction.translate`
      tanlansa **hech narsa qilmaydi** (`break`). `ChatMessage`ga `textOriginal` /
      `textTranslated` qo'shilib, bosilganda pufakcha matni **so'rovsiz** almashadi
      (ikkala matn allaqachon javobda keladi). **BE 8.1**
- [ ] **O'qilganlik kuzatuvi** — umuman yo'q. `ListView`dagi har xabar ko'rinishi kuzatiladi
      (`visibility_detector`), 500 ms debounce bilan buferlanib `POST /chats/{id}/read`ga
      **ro'yxat** sifatida yuboriladi. Chat yopilganda/fonga o'tganda bufer darhol
      bo'shatiladi. Mezon: xabar ≥50% ko'rinib ≥500 ms tursa. **BE 8.7**
- [ ] **Sana ajratkichi** — hozir bitta hardcoded "Bugun" chipi. `created_at` bo'yicha haqiqiy
      guruhlash ("Bugun" / "Kecha" / sana).
- [ ] **Ovoz yozish** — `chat_record_time` = `'0:00'` **statik matn**, o'smaydi va hech narsa
      yozilmaydi. Haqiqiy yozish + taymer (`record` paketi).
- [ ] **Ovozli xabar ijrosi** — play/download ikonkalari bor, lekin **ijro yo'q**
      (`just_audio`). `voiceDownloaded` — qurilma keshi holati, backenddan kelmaydi.
- [ ] **Rasm/fayl yuklash** — `PickAttachment` mock xabar qo'shadi.
      `POST /chats/media` → `POST /messages` oqimiga ulanadi. **BE 8.5**
- [ ] **Mahsulot biriktirish** — foydalanuvchining o'z mahsulotlarini tanlash ekrani kerak
      (`GET /users/me/products`).
- [ ] **Kontakt biriktirish** — `flutter_contacts` paketi kerak.
- [ ] **Joylashuv** — `geolocator` bor. Koordinata olinadi; masofa (`1.2 km`) **klientda**
      hisoblanadi (backend faqat `latitude`/`longitude` yuboradi). **BE 8.3.1**
- [ ] `client_message_id` (UUID) generatsiya qilinadi — optimistik UI va WS echo
      dublikatini oldini olish uchun. **BE 8.4**
- [ ] **Typing indikatori** — UI elementi yo'q. App bar'da "yozmoqda..." qo'shiladi. **BE 8.9**
- [x] **App bar menyusi (⋮)** — `onMenu: () {}` bo'sh. Bloklash / suhbatni tozalash /
      profilga o'tish (Maxfiylik moduli bosqichida).

---

## 9. Do'stlar — BE 9

### 9.1 ⚠️ Yetishmayotgan ekran (MUHIM)
**Kelgan do'stlik so'rovlarini qabul qilish/rad etish uchun hech qanday ekran yo'q** — ya'ni
hozirgi UI'da do'stlik **hech qachon yakunlanmaydi**.

- [ ] Yangi ekran: **"Do'stlik so'rovlari"** — `GET /friends/requests?type=incoming`,
      har element uchun Qabul / Rad tugmalari. **BE 9.4**
- [ ] Do'stlar ekrani sarlavhasiga so'rovlar soni bilan kirish tugmasi
      (`pending_incoming_count`). **BE 9.2**
- [ ] `FriendActionState` enumiga **`accept`** holati qo'shiladi (menga so'rov yuborgan odam
      qidiruvda chiqsa "Qabul qilish" tugmasi ko'rinadi). Hozir faqat
      `add` / `message` / `requested`.

### 9.2 Qolgan tasklar
- [ ] `friends_screen.dart` → `GET /friends`. Hozir `kMockFriends`.
- [ ] **Do'st qidirish faqat raqam bo'yicha** — `add_friend_search_hint` hozir
      *"ism, @username, telefon"*. **"Raqam bilan qidiring"** ga o'zgartiriladi +
      `TextInputType.number`. **BE 9.3.0**
- [ ] `add_friend_screen.dart` → `GET /users/search?query=` (debounce ~300ms). Qidiruv bo'sh
      bo'lsa ro'yxat **bo'sh** bo'ladi — hozir mock doim ko'rinadi.
- [ ] `SendFriendRequest` → `POST /friends/requests`. Hozir TODO.
- [ ] **So'rovni bekor qilish** — "So'rov yuborildi" tugmasi hozir **bosilmaydi**
      (`onTap: isRequested ? null : onAction`). Bosilganda tasdiq oynasi →
      `DELETE /friends/requests/{id}`.
- [ ] **Do'stlikdan chiqarish** UI yo'q — uzoq bosish yoki profil menyusi orqali.
- [ ] `OpenChat` → TODO. `POST /chats` → chat ekraniga. **BE 7.5**
- [ ] **Do'st status matni** (`"Onlayn · Nemis"`) mock tayyor matn. `is_online` /
      `last_seen_at` + `native_language` dan **klientda** yig'iladi. **BE 9.1**
- [ ] "Onlayn / Boshqalar" guruhlash `presence` WS eventi bilan real vaqtda yangilanadi.

---

## 10. Jonli muloqot — BE 10

> Bu ekran hozircha **to'liq dizayn maketi** — eng ko'p ish shu yerda.

- [ ] ⚠️ **Ovoz yozish umuman yo'q** — `StartSpeaking`/`StopSpeaking` faqat `mode` ni
      almashtiradi. `record` paketi + mikrofon ruxsati (`permission_handler` bor). **BE 10.5**
- [ ] ⚠️ **Audio ijro yo'q** — TTS javobini o'ynatadigan mexanizm yo'q (chatdagi ovozli xabar
      bilan **bir xil** ehtiyoj).
- [ ] ⚠️ **Obuna tekshiruvi yo'q** — Jonli tab hammaga ochiq. Basic tarifda "Premium kerak"
      ekrani/modali ko'rsatiladi (`403 SUBSCRIPTION_REQUIRED`). **BE 10.1**
- [ ] **Natijalar ro'yxati yo'q** — bitta statik demo karta (`_demoOriginal`,
      `_demoTranslated` hardcoded). Chat kabi **navbatlar ro'yxati** quriladi: har element —
      play tugmasi + tarjima matni + "aslini ko'rish". **BE 10.4**
- [ ] **"Mening tilim" standart qiymati** — `languageOptions[0]` (O'zbek) qattiq yozilgan.
      Profildagi `native_language` dan olinadi. **BE 10.3**
- [ ] **Til ro'yxati** — statik 7 ta til. `GET /live/languages` bilan filtrlanadi
      (STT/TTS bo'lmagan tillar o'chirilgan holatda ko'rsatiladi). **BE 10.2**
- [ ] **Sessiya tushunchasi yo'q** — ekran ochilganda `POST /live/sessions`, yopilganda `end`.
- [ ] Tillarni almashtirish (⇄) → `PATCH /live/sessions/{id}`.
- [ ] **Tarjima holati** — `jonli_translating` hozir statik dekor. So'rov davomida haqiqiy
      holat sifatida ko'rsatiladi.
- [ ] **Xatolik holati yo'q** — `NO_SPEECH_DETECTED` ("eshitilmadi, qayta urinib ko'ring") va
      tarmoq xatolari uchun ko'rinish kerak. **BE 10.9**

---

## 11. AnyLang raqamlari — BE 11

- [ ] ⚠️ **Raqamlar katalogi ekrani — umuman yo'q.** Yangi ekran: guruhlar bo'yicha tab/filtr,
      raqam qidirish, narx va bonus ko'rsatish, sotib olish. Profil yoki Sozlamalardan
      kiriladi. **BE 11.5**
- [ ] ⚠️ **"Mening raqamim" ko'rinishi yo'q.** Profilda raqam ko'rsatiladi
      (`O'zbekiston · 783 11 11`) + "almashtirish" tugmasi.
- [ ] Raqam formatlash va kiritish maskasi — 2.4-bo'lim.
- [ ] Rezervatsiya oqimi: to'lovga o'tishdan oldin `POST /numbers/reserve` (15 daqiqa).
      Vaqt hisoblagichi UI'da ko'rsatiladi. **BE 11.5.1**
- [ ] Bepul tasodifiy raqam olish: `POST /numbers/random` (90 kunda 1 marta —
      `429 NUMBER_CHANGE_COOLDOWN` holati ishlov beriladi). **BE 11.7**
- [ ] To'lov oqimi (5.7 to'lov moduli bilan birga).

---

## 12. Sozlamalar — BE (hali yozilmagan)

- [ ] Bildirishnoma tugmalari (`ToggleNotification`) hozir faqat lokal holat — backendga
      saqlanadigan qilinadi.
- [ ] "Profil ko'rinishi", "Bloklangan foydalanuvchilar", "Parolni o'zgartirish" —
      `OpenProfileVisibility` / `OpenBlockedUsers` / `OpenChangePassword` hozir bo'sh
      (`break`). Ekranlar quriladi.
- [ ] "Hisobdan chiqish" → `POST /auth/logout` + Hive tozalash + socket uzish.

---

## 13. Dizayn/UI kichik farqlar (API'ga ta'siri yo'q)

- [ ] **Xabarlar ekrani:** dizaynda sarlavha yonida qidiruv tugmasi (🔍) bor, kodda esa
      qidiruv maydoni doim ko'rinadi. Qaysi biri to'g'ri — hal qilinadi.
