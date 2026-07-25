import 'package:flutter/material.dart';

import '../utils/size_controller.dart';
import 'product_capabilities.dart';
import 'theme/colors.dart';

/// ✅ Breathable · Export Quality · OEM Available
class ProductCapabilitiesView extends StatelessWidget {
  final List<String> codes;
  final bool compact;

  const ProductCapabilitiesView({
    super.key,
    required this.codes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    final c = context.appColors;

    return Wrap(
      spacing: compact ? 6.dp : 8.dp,
      runSpacing: compact ? 4.dp : 6.dp,
      children: [
        for (final code in codes) _chip(c, productCapabilityLabel(code)),
      ],
    );
  }

  Widget _chip(AppColors c, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.dp : 10.dp,
        vertical: compact ? 5.dp : 7.dp,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: compact ? 14.dp : 16.dp,
            color: kOnline,
          ),
          SizedBox(width: compact ? 4.dp : 6.dp),
          Text(
            label,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: compact ? 11.sp : 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
