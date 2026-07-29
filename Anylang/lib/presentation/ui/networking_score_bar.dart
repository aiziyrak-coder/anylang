import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// LinkedIn-uslubidagi Networking Score qatori.
class NetworkingScoreBar extends StatelessWidget {
  final int connections;
  final int countries;
  final int? trust;
  final bool compact;

  const NetworkingScoreBar({
    super.key,
    required this.connections,
    required this.countries,
    this.trust,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final chips = <Widget>[
      _chip(
        c,
        '🤝',
        'networking_connections'.trParams({'n': _fmt(connections)}),
      ),
      _chip(
        c,
        '🌍',
        'networking_countries'.trParams({'n': _fmt(countries)}),
      ),
      if (trust != null)
        _chip(
          c,
          '⭐',
          'networking_trust'.trParams({'n': '${trust!.clamp(0, 100)}'}),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: 8.dp),
            chips[i],
          ],
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      final s = k == k.roundToDouble()
          ? '${k.toInt()}'
          : k.toStringAsFixed(1);
      return '${s}k';
    }
    return '$n';
  }

  Widget _chip(AppColors c, String emoji, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 13.sp)),
          SizedBox(width: 6.dp),
          Text(
            label,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
