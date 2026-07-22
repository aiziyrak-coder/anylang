import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Telegram-uslubidagi shisha (frosted) panel — orqa fonni blur qiladi.
class FrostedBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final double blurSigma;
  final AlignmentGeometry alignment;

  const FrostedBar({
    super.key,
    required this.child,
    this.padding,
    this.border,
    this.blurSigma = 22,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final tint = c.isDark
        ? const Color(0x6607111F)
        : const Color(0x73FFFFFF);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          alignment: alignment,
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
