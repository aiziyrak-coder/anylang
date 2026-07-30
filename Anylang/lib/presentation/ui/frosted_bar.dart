import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Frosted / liquid glass chrome — chat app bar + composer.
/// Wallpaper orqadan ko‘rinsin: pastroq alpha + kuchliroq blur.
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
    this.blurSigma = 40,
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c.isDark
                  ? const [
                      Color(0x99182A40),
                      Color(0xAA0E1826),
                      Color(0xB8121E2E),
                    ]
                  : const [
                      Color(0xCCFFFFFF),
                      Color(0xB8F4F7FB),
                      Color(0xD0FFFFFF),
                    ],
            ),
            border: border ??
                Border(
                  top: BorderSide(
                    color: c.isDark
                        ? const Color(0x40FFFFFF)
                        : const Color(0x66FFFFFF),
                    width: 0.8,
                  ),
                ),
            boxShadow: [
              BoxShadow(
                color: c.isDark
                    ? const Color(0x55000000)
                    : const Color(0x14071526),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top liquid highlight line
              Positioned(
                left: 24,
                right: 24,
                top: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        c.isDark
                            ? const Color(0x55FFFFFF)
                            : const Color(0xAAFFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                alignment: alignment,
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
