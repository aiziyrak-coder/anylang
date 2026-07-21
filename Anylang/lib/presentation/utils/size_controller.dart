import 'package:flutter/material.dart';

class SizeController {
  static double screenWidth = 393;
  static double screenHeight = 786;
  static double baseWidth = 393;
  static double baseHeight = 786;
  static double textScale = 1.0;
  static bool isTablet = false;

  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;

    // Web'da dastlabki frame'da haqiqiy canvas o'lchami hali kelmagan bo'lishi
    // mumkin (Size.zero) — bu holda eski/default qiymatlarni saqlaymiz, aks
    // holda .dp/.sp nolga tushib (masalan fontSize: 0) StrutStyle assertion
    // xatosini keltirib chiqaradi.
    if (width <= 0 || height <= 0) return;

    screenWidth = width;
    screenHeight = height;

    isTablet = screenWidth >= 600;

    if (isTablet) {
      baseWidth = 600;
      baseHeight = 1000;
    } else {
      baseWidth = 393;
      baseHeight = 786;
    }

    textScale = mediaQuery.textScaler.scale(1.0);
  }
}

extension SizeExtensions on num {
  // Ekran kengligiga moslashuv
  double get dp => this * (SizeController.screenWidth / SizeController.baseWidth);

  // Matn uchun: faqat ekran nisbati. Accessibility (textScale) ni
  // Flutter MediaQuery orqali o'zi qo'llaydi — ikki marta bo'lmasligi uchun.
  double get sp => this * (SizeController.screenWidth / SizeController.baseWidth);

  // Balandlikka moslashuv (agar kerak bo‘lsa)
  double get hp => this * (SizeController.screenHeight / SizeController.baseHeight);
}
