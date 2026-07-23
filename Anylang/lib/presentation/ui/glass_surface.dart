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
    this.blurSigma = 24,
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
        (c.isDark ? const Color(0xEE1A3148) : const Color(0xF5FFFFFF));

    final glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: showHairline
                ? Border.all(
                    color: c.isDark
                        ? const Color(0x28FFFFFF)
                        : const Color(0x66FFFFFF),
                    width: 0.8,
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
              boxShadow: c.glassShadow,
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

/// Full-bleed frosted chrome (nav / app bars / composers).
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
    this.blurSigma = 28,
    this.topEdge = true,
    this.bottomEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final tint =
        c.isDark ? const Color(0x99101828) : const Color(0xCCF4F7FB);
    final edge = BorderSide(
      color: c.isDark ? const Color(0x22FFFFFF) : const Color(0x140B1F36),
      width: 0.6,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: Border(
              top: topEdge ? edge : BorderSide.none,
              bottom: bottomEdge ? edge : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
