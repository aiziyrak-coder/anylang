import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Ekran fonini theme'ga mos, sodda va ishonchli B2B fon bilan to‘ldiradi.
/// Har content shuni eng tashqi qobiq sifatida ishlatadi.
///
/// Avvalgi liquid/animated gradient olib tashlandi — asosiy kontentga
/// e’tibor qaratish uchun.
class GradientBackground extends StatelessWidget {
  final Widget child;

  /// API mosligi uchun saqlangan (endi ishlatilmaydi).
  final Duration duration;

  const GradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 22),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        gradient: c.backgroundGradient,
      ),
      child: child,
    );
  }
}
