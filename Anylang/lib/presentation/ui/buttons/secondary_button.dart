import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import 'rich_button.dart';

/// AnyLang ikkilamchi (secondary) tugmasi — surface fon + outline chegara.
/// Ichkarida `RichButton` (Material + InkWell ripple) ishlatiladi.
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
        color: c.surface,
        borderRadius: radius,
        border: Border.all(color: c.surfaceBorder, width: 1.4),
      ),
    );
  }
}
