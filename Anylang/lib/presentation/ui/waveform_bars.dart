import 'package:flutter/material.dart';
import '../utils/size_controller.dart';

/// Ovoz to'lqini — yumaloq uchli vertikal barlar qatori. Ovozli xabar
/// (`ChatMessageItem`) va ovoz yozish paneli (`ChatComposer`) ikkalasida
/// ishlatiladi. Rangi chaqiruvchi tomonidan tema tokenidan beriladi.
class WaveformBars extends StatelessWidget {
  final Color color;

  /// Eng baland barning balandligi (dp). Qolganlari shunga nisbatan.
  final double maxHeight;
  final int barCount;
  final double barWidth;
  final double gap;

  const WaveformBars({
    super.key,
    required this.color,
    this.maxHeight = 22,
    this.barCount = 26,
    this.barWidth = 2.5,
    this.gap = 3,
  });

  // Barlar balandligi uchun aniqlangan (deterministik) naqsh — 0..1 oralig'i.
  static const List<double> _pattern = [
    0.32, 0.55, 0.78, 1.0, 0.62, 0.36, 0.55, 0.86, 1.0, 0.7, 0.42, 0.3,
    0.5, 0.8, 1.0, 0.6, 0.36, 0.66, 0.9, 0.72, 0.44, 0.56, 0.8, 0.5, 0.34, 0.48,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < barCount; i++) ...[
          if (i > 0) SizedBox(width: gap.dp),
          Container(
            width: barWidth.dp,
            height: (_pattern[i % _pattern.length] * maxHeight).dp,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(barWidth.dp),
            ),
          ),
        ],
      ],
    );
  }
}
