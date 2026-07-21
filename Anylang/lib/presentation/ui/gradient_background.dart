import 'package:flutter/material.dart';
import 'theme/colors.dart';

/// Ekran fonini theme'ga mos gradient bilan to'ldiradi. Har content shuni
/// eng tashqi qobiq sifatida ishlatadi (light/dark almashganda avtomatik).
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.appColors.backgroundGradient),
      child: SizedBox.expand(child: child),
    );
  }
}
