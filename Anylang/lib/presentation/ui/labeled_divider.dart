import 'package:flutter/material.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// O'rtasida matn bo'lgan ajratgich (masalan "yoki").
class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final line = Expanded(child: Divider(color: c.outline, thickness: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.dp),
          child: Text(
            label,
            style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
          ),
        ),
        line,
      ],
    );
  }
}
