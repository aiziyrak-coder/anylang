import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../toggle_switch.dart';
import '../../utils/size_controller.dart';

/// Sozlamalar ro'yxatidagi bitta yoqish/o'chirish qatori (label + Switch).
class ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.dp),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ),
          ToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
