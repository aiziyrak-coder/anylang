import 'package:flutter/material.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Onboarding pager nuqtalari — faol nuqta cho'zilgan lime bo'ladi.
class PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const PageIndicator({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: 3.dp),
          width: active ? 22.dp : 8.dp,
          height: 8.dp,
          decoration: BoxDecoration(
            color: active ? c.accent : c.textFaint.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8.dp),
          ),
        );
      }),
    );
  }
}
