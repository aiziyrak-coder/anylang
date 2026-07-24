import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme/colors.dart';
import 'theme/gradients.dart';
import 'theme/theme_controller.dart';
import '../utils/size_controller.dart';

const List<ThemeMode> _kThemeModes = [ThemeMode.dark, ThemeMode.light, ThemeMode.system];

/// Tungi / Kunduzgi / Avto tanlash — pastki pill segmentli tanlagich (Figma
/// dizayni). Tanlangan segment lime indikatori bilan sirg'anib (slide)
/// o'tadi. Joriy temani `ThemeController`dan reaktiv o'qiydi va tanlanganda
/// [onSelect] chaqiradi.
class ThemeSelector extends StatelessWidget {
  final void Function(ThemeMode mode) onSelect;

  const ThemeSelector({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (!Get.isRegistered<ThemeController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<ThemeController>();

    return Obx(() {
      final current = controller.mode.value;
      final index = _kThemeModes.indexOf(current).clamp(0, _kThemeModes.length - 1);

      return Container(
        height: 43.dp,
        padding: EdgeInsets.all(4.dp),
        decoration: BoxDecoration(
          color: c.segmentTrackBg,
          borderRadius: BorderRadius.circular(12.dp),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment(-1 + index * (2 / (_kThemeModes.length - 1)), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / _kThemeModes.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: limeButtonGradient,
                    borderRadius: BorderRadius.circular(9.dp),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _segment(c, 'theme_dark'.tr, ThemeMode.dark, current),
                _segment(c, 'theme_light'.tr, ThemeMode.light, current),
                _segment(c, 'theme_system'.tr, ThemeMode.system, current),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _segment(AppColors c, String label, ThemeMode mode, ThemeMode current) {
    final selected = mode == current;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(mode),
          borderRadius: BorderRadius.circular(9.dp),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: selected ? c.onAccent : c.textSecondary,
                fontSize: 12.5.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
