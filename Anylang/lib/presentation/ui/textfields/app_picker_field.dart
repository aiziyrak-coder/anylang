import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Bosilib ochiladigan (date picker / dropdown) label + qiymatli maydon.
class AppPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? leading;

  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasValue = value != null && value!.isNotEmpty;
    final radius = BorderRadius.circular(14.dp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.dp),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: radius,
                border: Border.all(color: c.surfaceBorder, width: 1.4),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 18.dp),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, SizedBox(width: 10.dp)],
                  Expanded(
                    child: Text(
                      hasValue ? value! : hint,
                      style: TextStyle(
                        color: hasValue ? c.textPrimary : c.textFaint,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(icon, color: c.textSecondary, size: 20.dp),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
