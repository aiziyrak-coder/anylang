import 'package:flutter/material.dart';
import 'colors.dart';

/// Light / dark `ThemeData` — ranglar `AppColors` ThemeExtension orqali
/// uzatiladi. UI `context.appColors` bilan o'qiydi.
abstract final class AppTheme {
  static ThemeData light = _build(lightAppColors);
  static ThemeData dark = _build(darkAppColors);

  static ThemeData _build(AppColors c) {
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.background,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: c.brightness,
        surface: c.background,
      ),
      extensions: [c],
    );
  }
}
