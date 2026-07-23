import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Frosted panel — prefers [GlassBar] for full-bleed chrome; kept for chat.
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
    this.blurSigma = 28,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final tint =
        c.isDark ? const Color(0xEE101C2C) : const Color(0xF2F7F9FC);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          alignment: alignment,
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: border ??
                Border(
                  top: BorderSide(color: c.outline, width: 0.6),
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
