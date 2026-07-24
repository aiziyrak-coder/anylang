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
    this.blurSigma = 32,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.isDark
                  ? const [
                      Color(0xC8243B55),
                      Color(0xE6121E2E),
                    ]
                  : const [
                      Color(0xF0FFFFFF),
                      Color(0xE6F1F5FA),
                    ],
            ),
            border: border ??
                Border(
                  top: BorderSide(
                    color: c.isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x22FFFFFF),
                    width: 0.7,
                  ),
                ),
          ),
          child: Container(
            alignment: alignment,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
