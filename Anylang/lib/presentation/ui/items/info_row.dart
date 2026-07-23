import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Profil info kartasining bitta qatori: ikon + yorliq + qiymat.
class InfoRow extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool showChevron;

  const InfoRow({
    super.key,
    this.iconAsset,
    this.icon,
    required this.label,
    this.value = '',
    this.valueColor,
    this.onTap,
    this.showChevron = false,
  }) : assert(iconAsset != null || icon != null, 'iconAsset yoki icon berilishi shart');

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
      child: Row(
        children: [
          iconAsset != null
              ? SvgPicture.asset(
                  iconAsset!,
                  width: 18.dp,
                  height: 18.dp,
                  colorFilter: ColorFilter.mode(c.textSecondary, BlendMode.srcIn),
                )
              : Icon(icon, size: 18.dp, color: c.textSecondary),
          SizedBox(width: 12.dp),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty) ...[
            SizedBox(width: 8.dp),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? c.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (showChevron) ...[
            SizedBox(width: 4.dp),
            Icon(Icons.chevron_right_rounded, size: 20.dp, color: c.textSecondary),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
