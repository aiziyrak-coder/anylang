import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Kartochka / preview ustidagi ▶ 15s badge.
class ProductVideoBadge extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const ProductVideoBadge({
    super.key,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(99.dp);
    final padH = compact ? 7.dp : 10.dp;
    final padV = compact ? 3.dp : 5.dp;

    final child = Ink(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(color: c.accent.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            color: c.accent,
            size: compact ? 14.dp : 16.dp,
          ),
          SizedBox(width: 2.dp),
          Text(
            'product_video_15s_badge'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10.sp : 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return IgnorePointer(child: child);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
