import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Ekran fonini theme'ga mos, sekin harakatlanuvchi liquid gradient bilan
/// to'ldiradi. Har content shuni eng tashqi qobiq sifatida ishlatadi.
class GradientBackground extends StatefulWidget {
  final Widget child;

  /// To‘liq animatsiya sikli (u yoqdan bu yoqqa). Sekinroq = kattaroq qiymat.
  final Duration duration;

  const GradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 22),
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _ctrl.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final palette = c.isDark ? _DarkPalette.colors : _LightPalette.colors;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final t2 = Curves.easeInOut.transform(
          ((_ctrl.value + 0.35) % 1.0),
        );

        final begin = Alignment.lerp(
          const Alignment(-1.15, -1.05),
          const Alignment(-0.15, -1.2),
          t,
        )!;
        final end = Alignment.lerp(
          const Alignment(1.1, 1.15),
          const Alignment(0.25, 1.25),
          t,
        )!;

        final glowA = Alignment.lerp(
          const Alignment(-0.85, -0.65),
          const Alignment(0.75, -0.15),
          t,
        )!;
        final glowB = Alignment.lerp(
          const Alignment(0.9, 0.85),
          const Alignment(-0.7, 0.55),
          t2,
        )!;

        // Soft color breathe — intermediate stops shift slightly.
        final mid = Color.lerp(palette[1], palette[2], t * 0.55)!;
        final deep = Color.lerp(palette[2], palette[3], t2 * 0.4)!;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    palette[0],
                    mid,
                    deep,
                    palette[3],
                  ],
                  stops: const [0.0, 0.32, 0.68, 1.0],
                ),
              ),
            ),
            // Ambient accent bloom (very soft)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: glowA,
                  radius: 1.15,
                  colors: [
                    palette.accentBloom.withValues(alpha: c.isDark ? 0.22 : 0.18),
                    palette.accentBloom.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: glowB,
                  radius: 1.05,
                  colors: [
                    palette.coolBloom.withValues(alpha: c.isDark ? 0.28 : 0.16),
                    palette.coolBloom.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            // Subtle vignette for depth
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(t * math.pi) * 0.08,
                    math.cos(t * math.pi) * 0.06,
                  ),
                  radius: 1.35,
                  colors: [
                    Colors.transparent,
                    (c.isDark ? const Color(0xFF02060C) : const Color(0xFFB8C4D4))
                        .withValues(alpha: c.isDark ? 0.35 : 0.12),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Palette {
  final List<Color> colors;
  final Color accentBloom;
  final Color coolBloom;

  const _Palette({
    required this.colors,
    required this.accentBloom,
    required this.coolBloom,
  });

  Color operator [](int i) => colors[i];
}

abstract final class _LightPalette {
  static const colors = _Palette(
    colors: [
      Color(0xFFF8FBFF),
      Color(0xFFE8F0F8),
      Color(0xFFD5E3F2),
      Color(0xFFE4EDF0),
    ],
    accentBloom: Color(0xFFB7E05A),
    coolBloom: Color(0xFF7EB6E8),
  );
}

abstract final class _DarkPalette {
  static const colors = _Palette(
    colors: [
      Color(0xFF030B14),
      Color(0xFF0A1C30),
      Color(0xFF123048),
      Color(0xFF0C2236),
    ],
    accentBloom: Color(0xFF7A9E2A),
    coolBloom: Color(0xFF1A4A6E),
  );
}
