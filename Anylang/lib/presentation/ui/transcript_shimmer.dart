import 'package:flutter/material.dart';

import '../utils/size_controller.dart';

/// Ovoz → matn / tarjima kutish shimmeri (chat + jonli).
class TranscriptShimmer extends StatefulWidget {
  final Color color;
  final double? width;

  const TranscriptShimmer({
    super.key,
    required this.color,
    this.width,
  });

  @override
  State<TranscriptShimmer> createState() => _TranscriptShimmerState();
}

class _TranscriptShimmerState extends State<TranscriptShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final a = 0.35 + _c.value * 0.55;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10.dp,
              width: widget.width ?? double.infinity,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: a),
                borderRadius: BorderRadius.circular(6.dp),
              ),
            ),
            SizedBox(height: 6.dp),
            Container(
              height: 10.dp,
              width: 110.dp,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: a * 0.85),
                borderRadius: BorderRadius.circular(6.dp),
              ),
            ),
          ],
        );
      },
    );
  }
}
