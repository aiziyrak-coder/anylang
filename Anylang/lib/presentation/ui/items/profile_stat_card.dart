import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../../utils/size_controller.dart';

/// Biznes profilidagi statistik ko'rsatkich kartasi (yengil gradient).
class ProfileStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? valueColor;
  final LinearGradient? gradient;
  final VoidCallback? onTap;

  const ProfileStatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final g = gradient ?? profileStatGradientA;
    final radius = BorderRadius.circular(16.dp);

    final child = Container(
      padding: EdgeInsets.symmetric(vertical: 12.dp, horizontal: 8.dp),
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: radius,
        border: Border.all(color: c.surfaceBorder, width: 0.7),
        boxShadow: c.glassShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18.dp, color: c.accentText),
            SizedBox(height: 6.dp),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? c.textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3.dp),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textFaint,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
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
