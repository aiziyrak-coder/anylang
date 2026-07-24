import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// iOS liquid / frosted glass card surface.
/// Soft fill + blur + optional hairline (no heavy frames).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final bool showHairline;
  final bool showShadow;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurSigma = 26,
    this.showHairline = true,
    this.showShadow = true,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = borderRadius ?? BorderRadius.circular(20.dp);
    final fill = tint ??
        (c.isDark ? const Color(0xE61A3148) : const Color(0xF2FFFFFF));

    final glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fill.withValues(alpha: c.isDark ? 0.92 : 0.97),
                fill.withValues(alpha: c.isDark ? 0.78 : 0.88),
              ],
            ),
            border: showHairline
                ? Border.all(
                    color: c.isDark
                        ? const Color(0x38FFFFFF)
                        : const Color(0x88FFFFFF),
                    width: 0.9,
                  )
                : null,
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );

    final shadowed = showShadow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                ...c.glassShadow,
                BoxShadow(
                  color: c.accent.withValues(alpha: c.isDark ? 0.08 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: glass,
          )
        : glass;

    if (onTap == null) return shadowed;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: shadowed,
      ),
    );
  }
}

/// Full-bleed frosted chrome (nav / app bars / composers) — liquid glass.
class GlassBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final bool topEdge;
  final bool bottomEdge;

  const GlassBar({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 34,
    this.topEdge = true,
    this.bottomEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final edge = BorderSide(
      color: c.isDark ? const Color(0x33FFFFFF) : const Color(0x22FFFFFF),
      width: 0.7,
    );

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
                      Color(0xB8243B55),
                      Color(0xCC121E2E),
                    ]
                  : const [
                      Color(0xE8FFFFFF),
                      Color(0xD6F1F5FA),
                    ],
            ),
            border: Border(
              top: topEdge ? edge : BorderSide.none,
              bottom: bottomEdge ? edge : BorderSide.none,
            ),
            boxShadow: [
              BoxShadow(
                color: c.isDark
                    ? const Color(0x44000000)
                    : const Color(0x14071526),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}
