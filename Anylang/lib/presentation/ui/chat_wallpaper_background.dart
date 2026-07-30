import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme/colors.dart';
import 'theme/gradients.dart';

/// Chat canvas — rasm yo‘q. Tiniq tema gradient + nozik mesh (liquid bubble
/// blur uchun yengil tekstura). Glass effekt faqat xabar bubble’da.
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: c.isDark
                  ? chatCanvasGradientDark
                  : chatCanvasGradientLight,
            ),
          ),
        ),
        // Soft brand wash — blur ushlashi uchun, lekin fon “toza” qoladi.
        Positioned(
          top: -80,
          right: -60,
          child: IgnorePointer(
            child: _SoftOrb(
              size: 220,
              color: c.accent.withValues(alpha: c.isDark ? 0.07 : 0.09),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -70,
          child: IgnorePointer(
            child: _SoftOrb(
              size: 260,
              color: kSpeakBlue.withValues(alpha: c.isDark ? 0.06 : 0.07),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ChatMeshPainter(
                ink: c.textPrimary.withValues(
                  alpha: c.isDark ? 0.045 : 0.035,
                ),
                accent: c.accent.withValues(
                  alpha: c.isDark ? 0.035 : 0.04,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Nozik diagonal “signal” chiziqlar + nuqtalar — Telegram doodle o‘rniga
/// minimal, o‘qilishi yuqori mesh.
class _ChatMeshPainter extends CustomPainter {
  final Color ink;
  final Color accent;

  _ChatMeshPainter({required this.ink, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = ink
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dot = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    const step = 28.0;
    final cols = (size.width / step).ceil() + 2;
    final rows = (size.height / step).ceil() + 2;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * step + (row.isOdd ? step * 0.5 : 0);
        final y = row * step;
        final seed = (row * 31 + col * 17) % 7;

        if (seed == 0 || seed == 3) {
          // Qisqa diagonal chiziq
          final len = 7.0 + (seed * 1.2);
          canvas.drawLine(
            Offset(x - len * 0.4, y + len * 0.35),
            Offset(x + len * 0.55, y - len * 0.2),
            dash,
          );
        } else if (seed == 1) {
          canvas.drawCircle(Offset(x, y), 1.15, dot);
        } else if (seed == 5) {
          // Mini arc — “signal”
          final r = 5.5;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: r),
            -math.pi * 0.15,
            math.pi * 0.55,
            false,
            dash,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatMeshPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.accent != accent;
}
