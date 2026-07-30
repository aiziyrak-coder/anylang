import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Chat orqa foni — AnyLang mavzusidagi doodle pattern
/// (chat, tarjima, globe, ovoz, AI). SVG tile emas — CustomPainter
/// (har doim ko‘rinadi, .dp bilan o‘lcham).
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final base = c.background;
    final ink = c.textFaint.withValues(alpha: c.isDark ? 0.32 : 0.28);

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AnyLangChatDoodlePainter(
                  color: ink,
                  tileW: 220.dp,
                  tileH: 340.dp,
                  iconSize: 28.dp,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AnyLangChatDoodlePainter extends CustomPainter {
  final Color color;
  final double tileW;
  final double tileH;
  final double iconSize;

  _AnyLangChatDoodlePainter({
    required this.color,
    required this.tileW,
    required this.tileH,
    required this.iconSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, iconSize * 0.055)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cols = (size.width / tileW).ceil() + 1;
    final rows = (size.height / tileH).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final ox = col * tileW;
        final oy = row * tileH;
        _paintTile(canvas, ox, oy, stroke, fill);
      }
    }
  }

  void _paintTile(
    Canvas canvas,
    double ox,
    double oy,
    Paint stroke,
    Paint fill,
  ) {
    final s = iconSize;
    // Joylashuvlar tile ichida — Telegramcha tarqoq, lekin kattaroq.
    final spots = <({Offset o, double rot, int kind})>[
      (o: Offset(0.10, 0.06), rot: -0.28, kind: 0), // chat
      (o: Offset(0.55, 0.05), rot: 0.18, kind: 1), // translate A/文
      (o: Offset(0.82, 0.14), rot: 0.05, kind: 2), // globe
      (o: Offset(0.22, 0.26), rot: -0.12, kind: 3), // mic
      (o: Offset(0.68, 0.28), rot: 0.22, kind: 4), // swap
      (o: Offset(0.08, 0.44), rot: 0.15, kind: 5), // headphones
      (o: Offset(0.48, 0.42), rot: -0.35, kind: 6), // send
      (o: Offset(0.80, 0.48), rot: 0.10, kind: 7), // sparkle AI
      (o: Offset(0.28, 0.60), rot: 0.20, kind: 8), // waveform
      (o: Offset(0.62, 0.62), rot: -0.15, kind: 2), // globe
      (o: Offset(0.12, 0.76), rot: 0.08, kind: 0), // chat
      (o: Offset(0.50, 0.78), rot: -0.20, kind: 1), // translate
      (o: Offset(0.82, 0.84), rot: 0.25, kind: 6), // send
      (o: Offset(0.38, 0.14), rot: 0.30, kind: 7), // sparkle
      (o: Offset(0.88, 0.68), rot: -0.10, kind: 3), // mic
    ];

    for (final spot in spots) {
      final center = Offset(ox + spot.o.dx * tileW, oy + spot.o.dy * tileH);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(spot.rot);
      canvas.translate(-s / 2, -s / 2);
      switch (spot.kind) {
        case 0:
          _chatBubble(canvas, s, stroke);
        case 1:
          _translate(canvas, s, stroke, fill);
        case 2:
          _globe(canvas, s, stroke);
        case 3:
          _mic(canvas, s, stroke, fill);
        case 4:
          _swap(canvas, s, stroke);
        case 5:
          _headphones(canvas, s, stroke);
        case 6:
          _send(canvas, s, stroke, fill);
        case 7:
          _sparkle(canvas, s, stroke, fill);
        case 8:
          _waveform(canvas, s, stroke);
      }
      canvas.restore();
    }
  }

  void _chatBubble(Canvas canvas, double s, Paint p) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.12, s * 0.78, s * 0.55),
      Radius.circular(s * 0.14),
    );
    canvas.drawRRect(r, p);
    final tail = Path()
      ..moveTo(s * 0.22, s * 0.66)
      ..lineTo(s * 0.18, s * 0.88)
      ..lineTo(s * 0.42, s * 0.66);
    canvas.drawPath(tail, p);
    canvas.drawLine(Offset(s * 0.22, s * 0.32), Offset(s * 0.68, s * 0.32), p);
    canvas.drawLine(Offset(s * 0.22, s * 0.46), Offset(s * 0.55, s * 0.46), p);
  }

  void _translate(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Chap: "A" harfi (lotin)
    final a = Path()
      ..moveTo(s * 0.10, s * 0.55)
      ..lineTo(s * 0.26, s * 0.12)
      ..lineTo(s * 0.42, s * 0.55);
    canvas.drawPath(a, stroke);
    canvas.drawLine(Offset(s * 0.16, s * 0.40), Offset(s * 0.36, s * 0.40), stroke);

    // O‘rtada swap strelkalari
    final midY = s * 0.42;
    canvas.drawLine(
      Offset(s * 0.48, midY - s * 0.10),
      Offset(s * 0.62, midY - s * 0.10),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.56, midY - s * 0.18),
      Offset(s * 0.62, midY - s * 0.10),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.48, midY + s * 0.10),
      Offset(s * 0.62, midY + s * 0.10),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.48, midY + s * 0.10),
      Offset(s * 0.54, midY + s * 0.18),
      stroke,
    );

    // O‘ng: oddiy "文" uslubidagi chiziqlar (glyph)
    canvas.drawLine(Offset(s * 0.70, s * 0.22), Offset(s * 0.92, s * 0.22), stroke);
    canvas.drawLine(Offset(s * 0.81, s * 0.18), Offset(s * 0.81, s * 0.58), stroke);
    canvas.drawLine(Offset(s * 0.70, s * 0.38), Offset(s * 0.92, s * 0.38), stroke);
    canvas.drawLine(Offset(s * 0.72, s * 0.38), Offset(s * 0.68, s * 0.58), stroke);
    canvas.drawLine(Offset(s * 0.90, s * 0.38), Offset(s * 0.94, s * 0.58), stroke);
  }

  void _globe(Canvas canvas, double s, Paint p) {
    final c = Offset(s / 2, s / 2);
    final r = s * 0.38;
    canvas.drawCircle(c, r, p);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 0.34, height: r * 2),
      p,
    );
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
    canvas.drawLine(
      Offset(c.dx - r * 0.85, c.dy - r * 0.45),
      Offset(c.dx + r * 0.85, c.dy - r * 0.45),
      p,
    );
    canvas.drawLine(
      Offset(c.dx - r * 0.85, c.dy + r * 0.45),
      Offset(c.dx + r * 0.85, c.dy + r * 0.45),
      p,
    );
  }

  void _mic(Canvas canvas, double s, Paint stroke, Paint fill) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.36, s * 0.12, s * 0.28, s * 0.42),
      Radius.circular(s * 0.14),
    );
    canvas.drawRRect(body, stroke);
    final arc = Path()
      ..moveTo(s * 0.22, s * 0.42)
      ..quadraticBezierTo(s * 0.22, s * 0.68, s * 0.50, s * 0.68)
      ..quadraticBezierTo(s * 0.78, s * 0.68, s * 0.78, s * 0.42);
    canvas.drawPath(arc, stroke);
    canvas.drawLine(Offset(s * 0.50, s * 0.68), Offset(s * 0.50, s * 0.82), stroke);
    canvas.drawLine(Offset(s * 0.34, s * 0.82), Offset(s * 0.66, s * 0.82), stroke);
  }

  void _swap(Canvas canvas, double s, Paint p) {
    // Vertical swap arrows (tarjima yo‘nalishi)
    canvas.drawLine(Offset(s * 0.32, s * 0.18), Offset(s * 0.32, s * 0.72), p);
    canvas.drawLine(Offset(s * 0.32, s * 0.18), Offset(s * 0.22, s * 0.32), p);
    canvas.drawLine(Offset(s * 0.32, s * 0.18), Offset(s * 0.42, s * 0.32), p);

    canvas.drawLine(Offset(s * 0.68, s * 0.28), Offset(s * 0.68, s * 0.82), p);
    canvas.drawLine(Offset(s * 0.68, s * 0.82), Offset(s * 0.58, s * 0.68), p);
    canvas.drawLine(Offset(s * 0.68, s * 0.82), Offset(s * 0.78, s * 0.68), p);
  }

  void _headphones(Canvas canvas, double s, Paint p) {
    final arc = Path()
      ..moveTo(s * 0.18, s * 0.48)
      ..quadraticBezierTo(s * 0.18, s * 0.12, s * 0.50, s * 0.12)
      ..quadraticBezierTo(s * 0.82, s * 0.12, s * 0.82, s * 0.48);
    canvas.drawPath(arc, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.10, s * 0.44, s * 0.20, s * 0.32),
        Radius.circular(s * 0.06),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.70, s * 0.44, s * 0.20, s * 0.32),
        Radius.circular(s * 0.06),
      ),
      p,
    );
  }

  void _send(Canvas canvas, double s, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(s * 0.12, s * 0.50)
      ..lineTo(s * 0.88, s * 0.18)
      ..lineTo(s * 0.55, s * 0.50)
      ..lineTo(s * 0.88, s * 0.82)
      ..close();
    canvas.drawPath(path, stroke);
    canvas.drawLine(Offset(s * 0.55, s * 0.50), Offset(s * 0.12, s * 0.50), stroke);
  }

  void _sparkle(Canvas canvas, double s, Paint stroke, Paint fill) {
    // AI / Sofiya sparkle
    void star(Offset c, double r) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = -math.pi / 2 + i * math.pi / 2;
        final outer = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
        final innerA = a + math.pi / 4;
        final inner = Offset(
          c.dx + math.cos(innerA) * r * 0.35,
          c.dy + math.sin(innerA) * r * 0.35,
        );
        if (i == 0) {
          path.moveTo(outer.dx, outer.dy);
        } else {
          path.lineTo(outer.dx, outer.dy);
        }
        path.lineTo(inner.dx, inner.dy);
      }
      path.close();
      canvas.drawPath(path, stroke);
    }

    star(Offset(s * 0.42, s * 0.45), s * 0.28);
    star(Offset(s * 0.72, s * 0.28), s * 0.12);
    star(Offset(s * 0.78, s * 0.68), s * 0.10);
  }

  void _waveform(Canvas canvas, double s, Paint p) {
    final bars = <double>[0.35, 0.55, 0.85, 0.50, 0.70, 0.40, 0.60];
    final gap = s * 0.10;
    final w = s * 0.07;
    var x = s * 0.16;
    for (final h in bars) {
      final top = s * (0.5 - h / 2);
      final bot = s * (0.5 + h / 2);
      canvas.drawLine(Offset(x, top), Offset(x, bot), p);
      x += gap + w;
    }
  }

  @override
  bool shouldRepaint(covariant _AnyLangChatDoodlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.tileW != tileW ||
        oldDelegate.tileH != tileH ||
        oldDelegate.iconSize != iconSize;
  }
}
