import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// `SegmentedToggle` uchun bitta segment ta'rifi (masalan "Oylik"/"Yillik").
class SegmentOption<T> {
  final T value;
  final String label;
  final String? badge; // masalan "-20%"

  const SegmentOption({required this.value, required this.label, this.badge});
}

/// Generic 2-3 bo'lakli segmentli tanlagich (masalan Oylik/Yillik obuna
/// davri). Tanlangan segment lime fonli bo'ladi, ixtiyoriy kichik badge bilan.
class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      padding: EdgeInsets.all(4.dp),
      child: Row(
        children: [
          for (final option in options) _segment(context, c, option),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, AppColors c, SegmentOption<T> option) {
    final selected = option.value == value;
    final radius = BorderRadius.circular(11.dp);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(option.value),
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : Colors.transparent,
              borderRadius: radius,
              border: selected ? Border.all(color: c.accent) : null,
            ),
            padding: EdgeInsets.symmetric(vertical: 12.dp),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    color: selected ? c.textPrimary : c.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (option.badge != null) ...[
                  SizedBox(width: 6.dp),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.dp, vertical: 2.dp),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(99.dp),
                    ),
                    child: Text(
                      option.badge!,
                      style: TextStyle(color: c.onAccent, fontSize: 10.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
