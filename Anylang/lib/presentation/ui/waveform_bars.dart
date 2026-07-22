import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/size_controller.dart';
import '../../data/audio/waveform_utils.dart';

/// Ovoz to'lqini — yumaloq uchli vertikal barlar. Statik naqsh yoki haqiqiy
/// amplitude [samples] bilan ishlaydi; [progress] ijro holatini bo'yaydi.
class WaveformBars extends StatelessWidget {
  final Color color;
  final Color? inactiveColor;

  /// Eng baland barning balandligi (dp).
  final double maxHeight;
  final int barCount;
  final double barWidth;
  final double gap;

  /// 0..1 amplitude (bo'sh bo'lsa deterministik naqsh).
  final List<double>? samples;

  /// Ijro progressi 0..1 — o'tgan barlar [color], qolganlari [inactiveColor].
  final double progress;

  /// Live yozishda scroll glide (ixtiyoriy).
  final ValueListenable<double>? scroll;

  const WaveformBars({
    super.key,
    required this.color,
    this.inactiveColor,
    this.maxHeight = 22,
    this.barCount = 26,
    this.barWidth = 2.5,
    this.gap = 3,
    this.samples,
    this.progress = 1,
    this.scroll,
  });

  static const List<double> _pattern = [
    0.32, 0.55, 0.78, 1.0, 0.62, 0.36, 0.55, 0.86, 1.0, 0.7, 0.42, 0.3,
    0.5, 0.8, 1.0, 0.6, 0.36, 0.66, 0.9, 0.72, 0.44, 0.56, 0.8, 0.5, 0.34, 0.48,
  ];

  List<double> _bars() {
    final raw = samples;
    if (raw == null || raw.isEmpty) {
      return List<double>.generate(barCount, (i) => _pattern[i % _pattern.length]);
    }
    // Live yozish: oxirgi N sample; tayyor xabar: resample.
    if (raw.length <= barCount) {
      final padded = List<double>.filled(barCount, 0.06);
      for (var i = 0; i < raw.length; i++) {
        padded[barCount - raw.length + i] = raw[i].clamp(0.06, 1.0);
      }
      return padded;
    }
    return WaveformUtils.resampleBars(raw, barCount);
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars();
    final inactive = inactiveColor ?? color.withValues(alpha: 0.35);

    Widget paint(double p) => CustomPaint(
          painter: _BarsPainter(
            bars: bars,
            progress: p,
            activeColor: color,
            inactiveColor: inactive,
            maxHeight: maxHeight.dp,
            barWidth: barWidth.dp,
            gap: gap.dp,
          ),
          size: Size(
            barCount * barWidth.dp + (barCount - 1) * gap.dp,
            maxHeight.dp,
          ),
        );

    if (scroll != null) {
      return ValueListenableBuilder<double>(
        valueListenable: scroll!,
        builder: (_, _, _) => paint(progress),
      );
    }
    return paint(progress);
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double maxHeight;
  final double barWidth;
  final double gap;

  _BarsPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.maxHeight,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final midY = size.height / 2;
    final minH = barWidth;
    final radius = Radius.circular(barWidth / 2);
    final active = Paint()
      ..color = activeColor
      ..isAntiAlias = true;
    final inactive = Paint()
      ..color = inactiveColor
      ..isAntiAlias = true;

    for (var i = 0; i < bars.length; i++) {
      final h = (minH + bars[i] * (maxHeight - minH)).clamp(minH, maxHeight);
      final cx = i * (barWidth + gap) + barWidth / 2;
      final played = (i + 0.5) / bars.length <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, midY), width: barWidth, height: h),
          radius,
        ),
        played ? active : inactive,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}
