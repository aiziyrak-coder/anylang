import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/gradients.dart';
import '../utils/size_controller.dart';

/// Custom yoqish/o'chirish tugmasi (Figma dizayni bo'yicha) — Material
/// `Switch`o'rniga ishlatiladi. Yoqilganda lime gradient fon + tema bo'yicha
/// tugma rangi, o'chganda tema bo'yicha xira fon + tugma rangi.
class ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    const trackWidth = 50.0;
    const trackHeight = 26.0;
    const thumbSize = 20.0;
    const inset = 3.0;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: trackWidth.dp,
        height: trackHeight.dp,
        padding: EdgeInsets.all(inset.dp),
        decoration: BoxDecoration(
          gradient: value ? limeButtonGradient : null,
          color: value ? null : c.toggleTrackOff,
          borderRadius: BorderRadius.circular(99.dp),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize.dp,
            height: thumbSize.dp,
            decoration: BoxDecoration(
              color: value ? c.toggleThumbOn : c.toggleThumbOff,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
