import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../../utils/size_controller.dart';
import 'rich_button.dart';

/// AnyLang asosiy (primary) tugmasi — lime gradient + glow. Ichkarida
/// `RichButton` (Material + InkWell ripple) ishlatiladi.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final Widget? endIcon;
  final Widget? startIcon;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.endIcon,
    this.startIcon,
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
      loadingCircleColor: c.onAccent,
      textColor: c.onAccent,
      textStyle: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: c.onAccent,
      ),
      padding: EdgeInsets.symmetric(vertical: 18.dp, horizontal: 20.dp),
      borderRadius: radius,
      decoration: BoxDecoration(
        gradient: limeButtonGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: kLime.withValues(alpha: enabled ? 0.35 : 0),
            blurRadius: 24.dp,
            offset: Offset(0, 8.dp),
          ),
        ],
      ),
    );
  }
}
