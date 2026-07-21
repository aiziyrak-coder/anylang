import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Jins tanlash — segmentli (Ayol / Erkak). Tanlangan segment lime.
class GenderSelector extends StatelessWidget {
  final String value; // 'female' | 'male'
  final void Function(String value) onSelect;

  const GenderSelector({super.key, required this.value, required this.onSelect});

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
          _seg(context, 'female', 'female'.tr, c),
          _seg(context, 'male', 'male'.tr, c),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String key, String label, AppColors c) {
    final selected = value == key;
    final radius = BorderRadius.circular(11.dp);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(key),
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? c.accent : Colors.transparent,
              borderRadius: radius,
            ),
            padding: EdgeInsets.symmetric(vertical: 12.dp),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? c.onAccent : c.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
