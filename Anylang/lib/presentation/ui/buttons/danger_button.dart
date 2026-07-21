import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import 'rich_button.dart';

/// AnyLang xavfli (danger) tugmasi — chiqish / hisobni o'chirish kabi amallar
/// uchun. Qizil tint fon + qizil chegara, ikkala temada ham bir xil rangda.
class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final Widget? startIcon;

  const DangerButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.startIcon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.all(Radius.circular(18.dp));

    return RichButton(
      text: text,
      onTap: onTap,
      isLoading: isLoading,
      enabled: enabled,
      iconNearText: true,
      startIcon: startIcon,
      loadingCircleColor: kListenRed,
      textColor: kListenRed,
      textStyle: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: kListenRed,
      ),
      padding: EdgeInsets.symmetric(vertical: 17.dp, horizontal: 20.dp),
      borderRadius: radius,
      decoration: BoxDecoration(
        color: kListenRed.withValues(alpha: 0.1),
        borderRadius: radius,
        border: Border.all(color: kListenRed.withValues(alpha: 0.4), width: 1.4),
      ),
    );
  }
}
