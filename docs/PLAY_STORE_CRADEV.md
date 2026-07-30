# Google Play — AnyLang (CraDev) birinchi release checklist

**Package:** `com.cradev.anylang`  
**App name:** AnyLang  
**Developer / publisher:** CraDev  
**Version:** `1.0.85+86`  
**Privacy:** https://anylang.uz/privacy/  
**Support:** support@anylang.uz  
**AAB (Play upload):** `dist/play/anylang-1.0.85+86.aab` (~85MB)  
**SHA-1 (upload key):** `B4:04:E7:C6:BF:B8:A7:B9:9B:17:88:D2:32:F5:9A:08:4E:B8:E7:C4`  
**SHA-256:** `86:A7:1D:7F:D4:A6:38:01:2E:08:65:F3:95:9E:4B:CC:80:CF:E9:79:0A:D1:3E:4B:B2:82:7C:92:28:C3:3D:F2`  
(See also `docs/play_release_sha.txt`)

> Windows’da Flutter CLI “failed to strip debug symbols” deb xato chiqarishi mumkin; AAB baribir yaroqli va Play’ga yuklash mumkin.

---

## 1) Play Console (siz qilasiz)

1. https://play.google.com/console — CraDev developer account ($25 one-time agar yangi).
2. **Create app** → AnyLang → default language (English yoki O‘zbek) → App → Free → declarations.
3. **App signing:** Google Play App Signing (default). Upload key = mavjud `anylang-release.jks`.
4. **Store listing** — quyidagi matnlar + assetlar.
5. **App content:** Data safety, Content rating, Target audience, News = No, Ads.
6. **Release → Internal testing** (tavsiya) yoki Production → AAB yuklash → Review.

---

## 2) Store listing matnlari

### Short description (max 80 belgi)

**EN:** Speak any language live. B2B chat, translate, marketplace — by CraDev.

**UZ:** Jonli tarjima, B2B chat va marketplace. AnyLang — CraDev.

**RU:** Живой перевод, B2B-чат и маркетплейс. AnyLang от CraDev.

### Full description (EN)

AnyLang by CraDev helps people and businesses communicate across languages.

• Live turn-based voice translation  
• Smart chat translation in 80+ languages  
• B2B networking and company profiles  
• Product marketplace with AnyTrade AI sourcing assistant  
• Business verification and trust signals  

Download AnyLang and grow global trade without language barriers.

Privacy: https://anylang.uz/privacy/  
Support: support@anylang.uz  
Website: https://anylang.uz/

### Full description (UZ)

AnyLang (CraDev) — tillararo muloqot va B2B savdo uchun.

• Jonli ovozli tarjima  
• Chatda aqlli tarjima (80+ til)  
• Biznes tarmoq va kompaniya profillari  
• Marketplace va AnyTrade AI yordamchi  
• Ishonch va verifikatsiya  

Maxfiylik: https://anylang.uz/privacy/  
Yordam: support@anylang.uz

### Full description (RU)

AnyLang от CraDev — общение и B2B-торговля без языкового барьера.

• Живой голосовой перевод  
• Умный перевод в чате (80+ языков)  
• Бизнес-сеть и профили компаний  
• Маркетплейс и помощник AnyTrade AI  
• Доверие и верификация  

Конфиденциальность: https://anylang.uz/privacy/  
Поддержка: support@anylang.uz

---

## 3) Assetlar (siz tayyorlaysiz / yuklaysiz)

| Asset | O‘lcham |
|-------|---------|
| App icon | 512×512 PNG |
| Feature graphic | 1024×500 PNG |
| Phone screenshots | kamida 2 (16:9 yoki 9:16) |

Launcher icon: `Anylang/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (asos sifatida).

---

## 4) Data safety (qisqa javoblar)

App **collects / uses** (typical for AnyLang):

| Data | Purpose | Notes |
|------|---------|-------|
| Name, email, phone/account | Account | Required for login |
| Photos / camera | Profile, products, OCR | User-initiated |
| Microphone / audio | Live translate, voice | User-initiated |
| Approximate / precise location | Nearby / map features | Optional / runtime permission |
| Messages / chat content | Core feature + translation | Processed on servers |
| App activity / diagnostics | Crash / performance | If collected |

- Data encrypted in transit: **Yes** (HTTPS)  
- Users can request deletion: **Yes** (account delete in app / support)  
- Sold: **No**

---

## 5) Google Cloud (Maps + Google Sign-In)

Release keystore fingerprints — `docs/play_release_sha.txt` ga yoziladi.

Cloud Console → API credentials / OAuth Android client:

- Package name: `com.cradev.anylang`
- SHA-1: (filedan)

Maps API key Android restriction: same package + SHA-1.

---

## 6) Content rating / audience

- Target age: **18+** (B2B) yoki **13+** agar bolalar yo‘q  
- Categories: **Business** yoki **Communication**  
- Ads in app: **No** (agar reklama yo‘q)

---

## 7) Release notes (1.0.85)

**EN:** First Play release under CraDev. Package `com.cradev.anylang`. AnyTrade AI knowledge, trust score fix, translation quality.

**UZ:** CraDev ostida birinchi Play relizi. Yangi package, AnyTrade AI bilimi, ishonch foizi va tarjima sifati.
