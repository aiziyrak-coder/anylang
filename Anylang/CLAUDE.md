# Navbat Service — Loyiha qoidalari (Architecture Rules)

Bu fayl loyihaning asosiy qoidalari. **Har bir task shu qoidalarga asoslanib bajariladi** —
toza kod yoziladi, yangi fayl kerak bo'lsa to'g'ri joyga (quyidagi tuzilishga ko'ra) yaratiladi.
Bu qoidalardan chiqilmaydi. So'ralmagan joyga kod qo'shilmaydi.

---

## 1. Umumiy tamoyillar

- **State management:** GetX (`GetxController`, `.obs`, `Obx`).
- **DI:** qo'lda `di/*_module.dart` modullari orqali (`Get.put` / `Get.find`).
- **Til:** UI matnlari `LanguageLocalizations` (uz/en/ru) orqali. Hardcoded matn faqat namuna bo'lsa.
- So'ralmagan refactor qilinmaydi; faqat so'ralgan joy o'zgartiriladi.

## 2. Papka tuzilishi

```
lib/
  data/          — repository implementatsiyalari, data source, modellar
  domain/        — use-case, abstraksiyalar, domain modellar
  di/            — *_module.dart (dependency injection)
  presentation/
    screens/<screen_name>/   — har screen alohida papka
    ui/                      — qayta ishlatiladigan widgetlar (buttons/, theme/, items/, ...)
      items/                 — ListView/GridView item widgetlari (har item alohida fayl)
    modal/                   — modal/bottom-sheet UI
    utils/                   — yordamchi vositalar
      screen_options/        — Screen arxitektura yadrosi (TEGILMAYDI, kengaytirilmaydi-faqat zarur bo'lsa)
      formatters/            — format helper'lar
  main.dart
```

## 3. Screen arxitekturasi (yadro)

Har bir ekran 3 qismdan iborat: **Screen** (logika) + **ScreenContent** (UI) + **ScreenWidget** (ko'prik, tegilmaydi).

### Har screen uchun fayllar (`presentation/screens/<name>/`)

| Fayl | Vazifa |
|---|---|
| `<name>_screen.dart` | `Screen`dan extend — logika, action handler, lifecycle, navigatsiya |
| `<name>_content.dart` | `ScreenContent`dan extend — **mobile** UI |
| `<name>_tablet_content.dart` | (ixtiyoriy) `ScreenContent`dan extend — tablet UI |
| `<name>_state.dart` | `GetxController` — faqat reaktiv holat (`.obs`) |
| `<name>_action.dart` | (ixtiyoriy) faqat shu screen'ga xos action'lar (`MyAction`dan) — 4-bo'limga qara |
| `<name>_body.dart`, ... | (ixtiyoriy) shu screen'ga xos kichik widgetlar |

### Dialog va Bottom Sheet fayllari (MAJBURIY nomlash)

Modal oynalar `Screen` arxitekturasidan **tashqarida** — ular `context` orqali ochiladigan
funksiyalardir (`showXxxDialog(context, ...)` / `showXxxBottomSheet(context, ...)`) va **joriy
oyna ustida** ochiladi (yangi Screen emas). Fayl nomlash qoidasi:

| Tur | Fayl suffiksi | Qayerda |
|---|---|---|
| **Dialog** (markazда ochiladigan) | `_dialog.dart` | screen'ga xos bo'lsa — o'sha screen papkasida; umumiy/qayta ishlatiladigan bo'lsa — `presentation/modal/` |
| **Bottom sheet** (pastdan chiqadigan) | `_bottom_sheet.dart` | xuddi shu qoida |

- **Screen'lar orasida** faqat `navigate(...)` (bizning usul) bilan o'tiladi.
- **Dialog / bottom sheet** joriy oyna ustida ochiladi, natijani `Future`da qaytaradi
  (`Navigator.pop(context, result)`), chaqiruvchi shu natija bilan state'ni yangilaydi.
- Bir nechta dialog bir xil qobiqni ulashsa — umumiy shell widget ajratiladi (masalan `edit_dialog_shell.dart`).

### Namuna

```dart
// onboarding_screen.dart
class OnboardingScreen extends Screen<OnboardingState, void> {
  OnboardingScreen() : super(
    mobileContent: OnboardingContent(),     // majburiy
    // tabletContent: OnboardingTabletContent(), // ixtiyoriy
  );

  @override
  Future<void> actionHandler(OnboardingState state, MyAction action) async {
    switch (action) {
      case Continue _: ...
      case Back _: ...
    }
  }
}
```

```dart
// onboarding_state.dart
class OnboardingState extends GetxController {
  RxInt currentPageIndex = 0.obs;
}
```

## 4. Action-only oqim (Effect YO'Q)

Bu loyihada **Effect qatlami yo'q**. UI'dan faqat **`MyAction`** keladi, va uni bitta
`actionHandler` boshqaradi — ham state, ham so'rov, ham navigatsiya shu yerda.

- Barcha action'lar `MyAction`dan extend qilinadi.
- UI'da: `sendAction(SomeAction())`.
- Handler'da har `case`: avval **state o'zgarishi**, keyin **so'rov / navigatsiya** tartibida yoziladi.

### Action'larni joylashtirish qoidasi

| Action turi | Qayerga | Misol |
|---|---|---|
| **Umumiy** — boshqa screen'larda ham ishlatsa bo'ladigan | `presentation/utils/screen_options/my_action.dart` ichiga, `MyAction`dan extend | `class Back extends MyAction {}`, `class Continue extends MyAction {}` |
| **Faqat shu screen'ga xos** | shu screen papkasida `<screen_nomi>_action.dart` fayli ochiladi | `onboarding_action.dart` → `class OnboardingAction extends MyAction {}` |

```dart
// presentation/screens/onboarding/onboarding_action.dart
import '../../utils/screen_options/my_action.dart';

class OnboardingAction extends MyAction {}   // faqat shu screen ishlatadi
// kerak bo'lsa shu faylga yana shu screen'ga xos action'lar qo'shiladi
```

Qoida: umumiy action `my_action.dart`'ni shishirib yubormasligi uchun — **screen'ga xos**
bo'lsa, har doim o'sha screen papkasidagi `<screen_nomi>_action.dart`da turadi.

```dart
@override
Future<void> actionHandler(S state, MyAction action) async {
  switch (action) {
    case Submit _:
      state.loading.value = true;   // 1) state
      await repo.save(...);          // 2) so'rov
      state.loading.value = false;
    case Back _:
      popBackNavigate();             // navigatsiya
  }
}
```

## 5. Lifecycle qoidalari (MUHIM)

Ikki daraja bor — qaysi biriga nima yozilishini farqlash shart:

| Daraja | Hook'lar | Necha marta | Nima yoziladi |
|---|---|---|---|
| **Screen** | `initState(payload)`, `uiBuildFinished()`, `dispose()` | **bir marta** (content almashsa ham qayta ishlamaydi) | **Network so'rovlar, og'ir bir martalik ishlar** |
| **Content** | `initContent()`, `uiBuildFinished(state)`, `onClose()` | **har content uchun** (mobile↔tablet almashganda qayta) | **Faqat UI resurslari**: `PageController`, `AnimationController`, listener (`ever`) |

Qoida:
- **Network / ma'lumot yuklash → `Screen.initState`** (yoki screen-level `uiBuildFinished`). Ma'lumot `state`da saqlanadi.
- **UI controller/listener → content'ning `initContent` / `onClose`**'ida (almashganda to'g'ri qayta yaratiladi/tozalanadi).
- `uiBuildFinished` haqiqiy frame chizilgandan keyin ishlaydi (post-frame) — `build()` ichidan signal berilmaydi.
- **`State` (GetxController) faqat oddiy boshlang'ich qiymatlar saqlaydi — logika yozilmaydi.**
  Local'dan o'qish (Hive, `Get.locale`, storage) va shunga bog'liq boshlang'ich qiymatlarni
  `state`ga berish **`Screen.initState`da** bajariladi, state konstruktorida emas.

## 6. Mobile / Tablet content

- `Screen`ga `mobileContent` (majburiy) va `tabletContent` (ixtiyoriy) beriladi.
- Tanlash `ScreenWidget` ichида **joriy kenglik**ka qarab avtomatik: `width >= 600` va `tabletContent != null` bo'lsa → tablet, aks holda mobile.
- **Reaktiv**: split-screen'da tablet mobile hajmiga qisqarsa → mobile content'ga o'tadi (lifecycle to'g'ri ko'chadi).
- Tablet alohida UI kerak bo'lmasa — `tabletContent` berilmaydi, mobile content ishlaydi.

## 7. Responsive o'lchamlar — `SizeController`

`presentation/utils/size_controller.dart`. `SizeController.init(context)` `main.dart`dagi
`GetMaterialApp.builder`da chaqiriladi (qo'shimcha hech qayerda init kerak emas).

Barcha **qattiq o'lchamlar `.dp`/`.sp` orqali yoziladi** (raw raqam emas):

```dart
SizedBox(height: 40.dp)              // o'lcham, padding, radius, kvadrat → .dp
EdgeInsets.all(18.dp)
fontSize: 20.sp                       // shrift o'lchami → .sp
```

- `.dp` — ekran kengligiga nisbatan masshtab (baza: mobile 393, tablet 600).
- `.sp` — shrift uchun (faqat kenglik nisbati; accessibility scaling'ni Flutter o'zi qo'shadi, ikki marta emas).
- `.hp` — balandlik nisbati (faqat kerak bo'lganda; kvadrat elementlarda ishlatma — buziladi).
- Yangi UI yozilganda raw `fontSize`/o'lcham qoldirilmaydi.

## 8. Toza kod odatlari

- Fayl nomlari `snake_case`, klasslar `PascalCase`.
- Bitta fayl = bitta asosiy mas'uliyat (screen / content / state / widget).
- `screen_options/` yadrosi (`screen.dart`, `screen_widget.dart`, `screen_content.dart`) — zarur bo'lmasa tegilmaydi.
- `withOpacity` o'rniga `.withValues()` (deprecation).
- Ortiqcha import qoldirilmaydi.

### Ranglar va gradientlar

- **Hech qachon content/widget ichida inline `Color(0x...)` yoki `LinearGradient(...)` yozilmaydi.**
- Ranglar — `presentation/ui/theme/colors.dart`, gradientlar — `presentation/ui/theme/gradients.dart`dan olinadi.
- Avval mavjudlari tekshiriladi: **biroz mos kelsa — o'shani ishlatamiz**. Mos kelmasa — o'sha
  fayllarga yangi rang/gradient **qo'shamiz**, keyin shu yerdan ishlatamiz.

#### Theme (light / dark) — MAJBURIY

Loyiha **light va dark** temani qo'llab-quvvatlaydi. Rang tokenlari `AppColors`
(`ThemeExtension`, `colors.dart`) orqali beriladi va UI'da **`context.appColors.<token>`**
bilan olinadi (theme almashganda avtomatik qayta chiziladi):

```dart
final c = context.appColors;
Text('...', style: TextStyle(color: c.textPrimary));
Container(color: c.surface, ...);
```

- Tokenlar: `background`, `backgroundGradient`, `surface`, `surfaceBorder`, `textPrimary`,
  `textSecondary`, `textFaint`, `accent` (lime), `onAccent`, `accentSoft`, `outline`, `logoTileBg`.
  Yangi semantik rang kerak bo'lsa — `AppColors`ga token qo'shiladi (light+dark qiymati bilan),
  keyin `context.appColors`dan ishlatiladi.
- Har ekran foni `ui/gradient_background.dart` (`GradientBackground`) bilan o'raladi (theme gradient).
- Tema `ThemeController` (`ui/theme/theme_controller.dart`, GetX, Hive'da saqlanadi) orqali
  almashadi — `setMode(ThemeMode.light/dark/system)`. `main.dart`da `theme/darkTheme/themeMode` ulangan.
- `colors.dart`dagi eski top-level tokenlar (`textDark`, `mainBackground`, ...) **legacy light-only** —
  yangi UI'da ishlatilmaydi, `context.appColors` ishlatiladi.

### Widget va tugmalarni ajratish

- Content (`build`) ichiga katta/takrorlanuvchi UI bo'laklari to'planmaydi — alohida widget'ga ajratiladi.
- **Screen papkasida** faqat `content` va **faqat shu screen'ga xos, boshqa joyda takrorlanmaydigan
  va umumiylashtirib bo'lmaydigan** widgetlar turadi (masalan `language_btn.dart` → `LanguageBtn`).
  Widget bir nechта screen'da ishlatilsa yoki umumiylashtirsa bo'ladigan bo'lsa — u screen papkasida
  qolmaydi, `presentation/ui/`ga chiqariladi.
- **Item'lar (ListView / GridView / kolonka item'lari) har doim `presentation/ui/items/`da bo'ladi** —
  screen papkasiga item yozilmaydi. Har item alohida fayl (masalan `ui/items/notification_item.dart`
  → `NotificationItem`).
- **Primary/asosiy tugmalar uchun `RichButton` (`ui/buttons/rich_button.dart`) ishlatiladi** —
  kerak bo'lsa `decoration` (gradient/shadow), `textStyle`, `endIcon` orqali sozlanadi. Takroriy
  lime primary tugma uchun `ui/buttons/primary_button.dart` (`PrimaryButton`) bor — u ichkarida
  `RichButton`ni o'raydi. Yangi tugma yozishdan oldin mavjud `ui/buttons/`dagilar tekshiriladi.
- **Ikon tugmalar uchun `MyIconButton` (`ui/buttons/my_icon_button.dart`) ishlatiladi.**
- **Ripple MAJBURIY:** bosiladigan har qanday element `Material` + `InkWell` (yoki `InkResponse`)
  bilan o'raladi — bosishda ripple ko'rinadi. `RichButton` va `MyIconButton` buni ichida bajaradi,
  shuning uchun tugmalar uchun to'g'ridan-to'g'ri shular ishlatiladi. Custom bosiladigan bo'lak
  (list item, chip, link, checkbox) uchun `Material(color: transparent)` + `InkWell(borderRadius: ...)`
  ishlatiladi (`GestureDetector` — faqat ripple kerak bo'lmaganda, masalan drag/tap-outside).

### Umumiy UI komponentlari (`presentation/ui/`)

Bir nechа ekranda takrorlanadigan UI bo'lagi har safar qaytadan yozilmaydi — `ui/`da bitta umumiy
widget bo'ladi va hamma joyda shu ishlatiladi (DRY). Yangi takrorlanuvchi UI uchqasi paydo bo'lsa,
avval `ui/`da mosi bor-yo'qligi tekshiriladi; bo'lmasa — shu yerga umumiy widget qo'shiladi.

| Komponent | Fayl | Vazifa |
|---|---|---|
| **`AppTopBar`** | `ui/app_top_bar.dart` | Orqaga qaytish tugmasi + sarlavhali yuqori panel. Ekranlar shuni ishlatadi (back+title kerak bo'lsa). `title` — chaqiruvchi tomonda `.tr` bilan beriladi, `onBack` — odatda `sendAction(Back())`, ixtiyoriy `trailing` va `titleStyle` bilan sozlanadi. |

## 9. Figma → Flutter: asset ko'chirish qoidasi

Figma dizaynidan UI'ni Flutter'ga ko'chirayotganda asset'lar quyidagicha joylanadi va nomlanadi:

| Asset turi | Papka | Nomlash | Misol |
|---|---|---|---|
| **Raster ikonка** (Figma'dagi img/png ikon) | `assets/images/` | boshiga `ic_` | `ic_clock.png` |
| **Bayroq** | `assets/images/` | `flag_<kod>` | `flag_uz.png`, `flag_ru.png`, `flag_en.png` |
| **Katta/oddiy rasm** (illustratsiya, banner) | `assets/images/` | rasm nomi (`.png`) | `queue.png`, `notification.png` |
| **SVG / vektor** | `assets/icons/` | ikon bo'lsa boshiga `ic_` | `ic_next.svg`, `ic_back.svg` |

Qoidalar:
- **Loyihada avvaldan bor asset qayta qo'shilmaydi** — `assets/images/` va `assets/icons/` tekshiriladi
  (masalan `logo_white.png`, `ic_next.svg` allaqachon bor — qaytadan eksport qilinmaydi).
- `pubspec.yaml`da `assets/images/` va `assets/icons/` papkalar butunligicha ulangan — yangi fayl
  qo'shilganda pubspec'ni tahrirlash shart emas.
- Raster rasm `Image.asset(...)`, SVG esa `SvgPicture.asset(...)` bilan ishlatiladi.
- Eksport: Figma'dan PNG `@4x` (retina uchun aniq), keyin to'g'ri papkaga to'g'ri nom bilan saqlanadi.

## 9.1. Rasm tanlash va ko'rsatish — MAJBURIY

Loyihada rasm bilan ishlash uchun ikkita umumiy modal bor — to'g'ridan-to'g'ri paket
ishlatilmaydi, har doim shular chaqiriladi:

| Vazifa | Fayl | Funksiya | Misol |
|---|---|---|---|
| **Rasm tanlash** (kamera/galereya) | `presentation/modal/image_picker.dart` | `pickImage(context)` → `Future<File?>` | `final file = await pickImage(context);` |
| **Rasmni katta ko'rsatish** (preview) | `presentation/modal/show_image_dialog.dart` | `showImageDialog(...)` | `showImageDialog(context: context, image: url, isNetwork: true);` |

Qoidalar:
- **`image_picker` paketi to'g'ridan-to'g'ri (`ImagePicker().pickImage(...)`) ishlatilmaydi** — faqat
  `modal/image_picker.dart`dagi `pickImage(context)` orqali. U kamera/galereya tanlash sheet'ini
  ko'rsatadi va `File?` qaytaradi.
- **Rasmni to'liq/zoom ko'rsatish (preview) kerak bo'lsa** — har doim `showImageDialog(...)` ishlatiladi
  (network uchun `isNetwork: true`, asset uchun `false`).
- Bu modallar ichidagi matnlar `language_localizations.dart` kalitlari orqali (`img_*`).

## 10. Lokalizatsiya (matnlar) — MAJBURIY

UI'dagi **hech qanday matn hardcoded yozilmaydi**. Barcha matnlar
`presentation/utils/language_localizations.dart`dagi `keys` map'ida kalit sifatida saqlanadi va
UI'da GetX `.tr` orqali chaqiriladi:

```dart
Text('select_language_title'.tr)
RichButton(text: 'continue'.tr, ...)
```

Qoidalar:
- **Matn qo'shilsa** → kalit `language_localizations.dart`ga qo'shiladi va **uchala til**
  (`uz_UZ`, `ru_RU`, `us_US`) uchun tarjimasi yoziladi. UI'da `'kalit'.tr` chaqiriladi.
- **Matn o'zgartirilsa** → localizationsdagi qiymat yangilanadi (UI'da emas).
- **Matn o'chirilsa** → kaliti localizationsdan ham o'chiriladi (uchala tildan).
- Bir matn bir necha joyda kerak bo'lsa — bitta kalit qayta ishlatiladi (dublikat kalit yo'q).
- **Istisno:** til nomlari (`O‘zbekcha`, `Русский`, `English`) tarjima qilinmaydi — ular har doim
  o'z tilida/skriptida qoladi.
