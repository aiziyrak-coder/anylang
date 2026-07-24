import 'package:flutter/material.dart';

abstract final class MyColors {
  static const Color mainBackground = Color(0xFFF7F7FC);
}

const Color mainBackground = Color(0xFFF7F7FC);
Color notActiveBtn = Color(0xFFEFEFEF);
Color notActiveText = Color(0xFF8C8F9F);
Color lightGray = Color(0xFFF7F7F7);
Color bluePrimary = Color(0xFF174BEA);
Color dividerColor = Color(0xFFE5EAF0);

Color textDark = Color(0xFF0F1729);
Color textMuted = Color(0xFF647189);
Color fieldBorder = Color(0x14000000);
Color fieldFill = Color(0xFFF5F5F7);
Color fieldLabel = Color(0xFF665CF2);
Color purplePrimary = Color(0xFF665CF2);

// Brand — light'da to'qroq lime (yorug' fonda ko'rinsin), dark'da yorqin.
const Color kLime = Color(0xFF8BC21A);
const Color kLimeBright = Color(0xFFD4F04A);
const Color kNavy = Color(0xFF071526);

const Color kOnline = Color(0xFF34C759);
const Color kAvatarFg = Color(0xFFF2F7FC);
const Color kSpeakBlue = Color(0xFF64D2FF);
const Color kListenRed = Color(0xFFFF453A);

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Brightness brightness;
  final Color background;
  final Gradient backgroundGradient;
  final Color surface;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color outline;
  final Color logoTileBg;
  final Color toggleTrackOff;
  final Color toggleThumbOn;
  final Color toggleThumbOff;
  final Color segmentTrackBg;

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

  /// Accent ustidagi matn — light'da oq/navy, dark'da navy.
  Color get accentText => isDark ? kLimeBright : const Color(0xFF2E4A08);

  LinearGradient get accentButtonGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFFD6F24E), Color(0xFFBCDD3E)]
            : const [Color(0xFF8BC21A), Color(0xFF6FA00F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: isDark
              ? const Color(0x88000000)
              : const Color(0x1A071526),
          blurRadius: isDark ? 20 : 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  Gradient get cardTintGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: isDark ? 0.14 : 0.12),
          isDark ? const Color(0xFF0C2136) : const Color(0xFFE8EEF6),
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

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Light: yorug' fon + to'q matn/ikon/akssent.
const AppColors lightAppColors = AppColors(
  brightness: Brightness.light,
  background: Color(0xFFF0F4F9),
  backgroundGradient: LinearGradient(
    colors: [
      Color(0xFFF8FBFF),
      Color(0xFFE8F0F8),
      Color(0xFFD5E3F2),
      Color(0xFFE4EDF0),
    ],
    stops: [0.0, 0.32, 0.68, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  surface: Color(0xFFFFFFFF),
  surfaceBorder: Color(0x22071526),
  textPrimary: Color(0xFF071526),
  textSecondary: Color(0xFF3A4D63),
  textFaint: Color(0xFF5C7088),
  accent: kLime,
  onAccent: Color(0xFF071526),
  accentSoft: Color(0x338BC21A),
  outline: Color(0x1A071526),
  logoTileBg: kNavy,
  toggleTrackOff: Color(0x33071526),
  toggleThumbOn: Colors.white,
  toggleThumbOff: Colors.white,
  segmentTrackBg: Color(0x1A071526),
);

/// Dark: qorong'u fon + yorqin matn/ikon/akssent.
const AppColors darkAppColors = AppColors(
  brightness: Brightness.dark,
  background: Color(0xFF06111F),
  backgroundGradient: LinearGradient(
    colors: [
      Color(0xFF030B14),
      Color(0xFF0A1C30),
      Color(0xFF123048),
      Color(0xFF0C2236),
    ],
    stops: [0.0, 0.32, 0.68, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  surface: Color(0xFF1A3148),
  surfaceBorder: Color(0x33FFFFFF),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFD0DCE8),
  textFaint: Color(0xFFA8B8C9),
  accent: kLimeBright,
  onAccent: Color(0xFF071526),
  accentSoft: Color(0x44D4F04A),
  outline: Color(0x28FFFFFF),
  logoTileBg: Color(0xFF122A44),
  toggleTrackOff: Color(0x44FFFFFF),
  toggleThumbOn: kNavy,
  toggleThumbOff: Color(0xFFE8F0F8),
  segmentTrackBg: Color(0x55000000),
);

extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? darkAppColors;
}
