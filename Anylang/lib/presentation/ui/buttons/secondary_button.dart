import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import 'rich_button.dart';

/// Ikkilamchi tugma — glass fill, hairline (og'ir hoshiya yo'q).
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final Widget? startIcon;
  final Widget? endIcon;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.startIcon,
    this.endIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.all(Radius.circular(18.dp));

    return RichButton(
      text: text,
      onTap: onTap,
      isLoading: isLoading,
      enabled: enabled,
      iconNearText: true,
      startIcon: startIcon,
      endIcon: endIcon,
      loadingCircleColor: c.textPrimary,
      textColor: c.textPrimary,
      textStyle: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      padding: EdgeInsets.symmetric(vertical: 17.dp, horizontal: 20.dp),
      borderRadius: radius,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x55152A42) : const Color(0xCCFFFFFF),
        borderRadius: radius,
        border: Border.all(color: c.surfaceBorder, width: 0.8),
        boxShadow: c.glassShadow,
      ),
    );
  }
}
