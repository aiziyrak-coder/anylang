import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Light / dark `ThemeData` — Manrope (UI) + Sora (sarlavhalar).
abstract final class AppTheme {
  static ThemeData light = _build(lightAppColors);
  static ThemeData dark = _build(darkAppColors);

  static ThemeData _build(AppColors c) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.background,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );
    final display = GoogleFonts.soraTextTheme(textTheme);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: display.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        headlineLarge: display.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        headlineSmall: display.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        titleLarge: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          height: 1.35,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          height: 1.35,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: c.textSecondary,
          height: 1.35,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.logoTileBg,
        onSecondary: c.textPrimary,
        error: const Color(0xFFB42318),
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        outline: c.outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        titleTextStyle: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          fontSize: 18,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1),
      extensions: [c],
    );
  }
}
