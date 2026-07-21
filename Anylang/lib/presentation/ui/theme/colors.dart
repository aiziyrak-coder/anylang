import 'package:flutter/material.dart';

abstract final class MyColors {
  static const Color mainBackground = Color(0xFFF7F7FC);
}

const Color mainBackground = Color(0xFFF7F7FC);
Color notActiveBtn = Color(0xFFEFEFEF);
Color notActiveText = Color(0xFF8C8F9F);
Color lightGray = Color(0xFFF7F7F7);
Color bluePrimary = Color(0xFF174BEA);
Color dividerColor = Color(0xFFC7C7C7);

// Dialog / surface tokens
Color textDark = Color(0xFF0F1729);
Color textMuted = Color(0xFF647189);
Color fieldBorder = Color(0xFFE2E8F0);
Color fieldFill = Color(0xFFF5F5F7);
Color fieldLabel = Color(0xFF665CF2);
Color purplePrimary = Color(0xFF665CF2);

// ---------------------------------------------------------------------------
// AnyLang brand + theme tizimi (light / dark)
// ---------------------------------------------------------------------------
// Brend akssenti — ikkala temada bir xil (navy + lime).
const Color kLime = Color(0xFFCBE84C);
const Color kNavy = Color(0xFF0A2340);

// Onlayn holat nuqtasi (avatar) — ikkala temada bir xil yashil.
const Color kOnline = Color(0xFF9FE870);
// Avatar ustidagi harf rangi (to'q fon uchun ochiq) — temaga bog'liq emas.
const Color kAvatarFg = Color(0xFFF2F7FC);
// Jonli muloqot — suhbatdosh gapirganda ko'k akssent (halqa/waveform).
const Color kSpeakBlue = Color(0xFF7CC4F5);
// Jonli muloqot — "Tinglanmoqda" qizil holati.
const Color kListenRed = Color(0xFFFF6B6B);

/// Semantik rang tokenlari. Har token light/dark uchun alohida qiymatga ega.
/// UI'da `context.appColors.<token>` orqali olinadi (ThemeExtension — theme
/// almashganda avtomatik qayta chiziladi).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Brightness brightness;
  final Color background;
  final Gradient backgroundGradient;
  final Color surface; // kartalar / input fill
  final Color surfaceBorder; // karta/input chegarasi
  final Color textPrimary;
  final Color textSecondary; // muted
  final Color textFaint; // hint / eng och
  final Color accent; // lime
  final Color onAccent; // lime ustidagi matn (navy)
  final Color accentSoft; // tanlangan holat uchun lime tint
  final Color outline; // divider / chegara
  final Color logoTileBg; // logo ortidagi navy kvadrat
  final Color toggleTrackOff; // ToggleSwitch — o'chgan holat foni
  final Color toggleThumbOn; // ToggleSwitch — yoqilgan holat dumaloq tugmasi
  final Color toggleThumbOff; // ToggleSwitch — o'chgan holat dumaloq tugmasi
  final Color segmentTrackBg; // ThemeSelector kabi pill-segment tanlagich foni

  const AppColors({
    required this.brightness,
    required this.background,
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.outline,
    required this.logoTileBg,
    required this.toggleTrackOff,
    required this.toggleThumbOn,
    required this.toggleThumbOff,
    required this.segmentTrackBg,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Fon/surface ustida to'g'ridan-to'g'ri yoziladigan akssent matn uchun —
  /// light temada `accent` (lime) past kontrastli, shuning uchun to'qroq
  /// soya ishlatiladi; dark temada oddiy `accent` bilan bir xil.
  Color get accentText => isDark ? accent : const Color(0xFF7D8A1E);

  /// Onboarding illyustratsiya kartasi foni — yuqorida akssent tint, pastda
  /// surface'ga o'tuvchi nozik gradient.
  Gradient get cardTintGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: isDark ? 0.12 : 0.16),
          isDark ? const Color(0xFF0C2136) : const Color(0xFFF3F6FB),
        ],
      );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? background,
    Gradient? backgroundGradient,
    Color? surface,
    Color? surfaceBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? outline,
    Color? logoTileBg,
    Color? toggleTrackOff,
    Color? toggleThumbOn,
    Color? toggleThumbOff,
    Color? segmentTrackBg,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      outline: outline ?? this.outline,
      logoTileBg: logoTileBg ?? this.logoTileBg,
      toggleTrackOff: toggleTrackOff ?? this.toggleTrackOff,
      toggleThumbOn: toggleThumbOn ?? this.toggleThumbOn,
      toggleThumbOff: toggleThumbOff ?? this.toggleThumbOff,
      segmentTrackBg: segmentTrackBg ?? this.segmentTrackBg,
    );
  }

  // Theme o'zgarishi bir zumda (snap) bo'ladi — oraliq lerp shart emas.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

const AppColors lightAppColors = AppColors(
  brightness: Brightness.light,
  background: Color(0xFFF5F8FC),
  backgroundGradient: LinearGradient(
    colors: [Color(0xFFF7F9FC), Color(0xFFE9EEF5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  surface: Color(0xFFFFFFFF),
  surfaceBorder: Color(0xFFE6ECF3),
  textPrimary: Color(0xFF0B2545),
  textSecondary: Color(0xFF5E6E85),
  textFaint: Color(0xFF93A0B4),
  accent: kLime,
  onAccent: kNavy,
  accentSoft: Color(0x24CBE84C),
  outline: Color(0xFFE6ECF3),
  logoTileBg: kNavy,
  toggleTrackOff: Color(0x260B2545),
  toggleThumbOn: Colors.white,
  toggleThumbOff: Colors.white,
  segmentTrackBg: Color(0x0D0B2545),
);

const AppColors darkAppColors = AppColors(
  brightness: Brightness.dark,
  background: Color(0xFF0A2340),
  backgroundGradient: LinearGradient(
    colors: [Color(0xFF071B31), Color(0xFF0A2340), Color(0xFF07203A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  surface: Color(0x0DFFFFFF),
  surfaceBorder: Color(0x14FFFFFF),
  textPrimary: Color(0xFFEAF1F8),
  textSecondary: Color(0xFF8FA3BB),
  textFaint: Color(0xFF6E829B),
  accent: kLime,
  onAccent: kNavy,
  accentSoft: Color(0x1FCBE84C),
  outline: Color(0x1AFFFFFF),
  logoTileBg: Color(0xFF0F2A49),
  toggleTrackOff: Color(0x1FFFFFFF),
  toggleThumbOn: kNavy,
  toggleThumbOff: Color(0xFF8FA3BB),
  segmentTrackBg: Color(0x40000000),
);

/// UI'da qisqa foydalanish uchun: `context.appColors.background`.
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? darkAppColors;
}
