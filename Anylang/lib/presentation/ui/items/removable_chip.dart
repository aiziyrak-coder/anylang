import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Olib tashlanadigan chip (masalan sertifikat nomi + x). `RemovableChip.add`
/// konstruktori esa "+ Qo'shish" ko'rinishidagi qo'shish chipini beradi.
class RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool isAdd;

  const RemovableChip({
    super.key,
    required this.label,
    this.onRemove,
  })  : onTap = null,
        isAdd = false;

  const RemovableChip.add({
    super.key,
    required this.label,
    required VoidCallback this.onTap,
  })  : onRemove = null,
        isAdd = true;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(12.dp);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isAdd ? Icons.add_rounded : Icons.check_circle_rounded,
          size: 16.dp,
          color: isAdd ? c.textSecondary : c.accent,
        ),
        SizedBox(width: 6.dp),
        Text(
          label,
          style: TextStyle(
            color: isAdd ? c.textSecondary : c.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onRemove != null) ...[
          SizedBox(width: 6.dp),
          Icon(Icons.close_rounded, size: 15.dp, color: c.textFaint),
        ],
      ],
    );

    final decorated = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 9.dp),
      decoration: BoxDecoration(
        color: isAdd ? Colors.transparent : c.accentSoft,
        borderRadius: radius,
        border: Border.all(color: isAdd ? c.surfaceBorder : c.accent),
      ),
      child: content,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: isAdd ? onTap : onRemove,
        child: decorated,
      ),
    );
  }
}
