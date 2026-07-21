import 'package:flutter/material.dart';
import '../../utils/size_controller.dart';

/// Umumiy kichik yorliq (pill): ixtiyoriy ikon + matn. PREMIUM/BUSINESS
/// belgilari, "JORIY TARIF"/"SOTUVCHILAR" chiplari va shunga o'xshash
/// joylarda qayta ishlatiladi.
class PillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double fontSize;

  const PillBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.borderColor,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 5.dp),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99.dp),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize.sp + 2.dp, color: foreground),
            SizedBox(width: 4.dp),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: fontSize.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
