import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Onboarding slaydlaridagi tepadagi illyustratsiya kartalari (Flutter'da
/// qayta chizilgan — asset emas). Har biri bir xil qobiqni ([_OnbCard])
/// ulashadi.

class _OnbCard extends StatelessWidget {
  final Widget child;
  const _OnbCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      height: 250.dp,
      padding: EdgeInsets.all(20.dp),
      decoration: BoxDecoration(
        gradient: c.cardTintGradient,
        borderRadius: BorderRadius.circular(28.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: child,
    );
  }
}

/// 1-slayd: chat ko'rinishi (tarjima).
class OnbChatIllustration extends StatelessWidget {
  const OnbChatIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return _OnbCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bubble(
            context,
            text: 'onb1_msg_in'.tr,
            bg: c.surface,
            textColor: c.textPrimary,
            border: c.surfaceBorder,
          ),
          SizedBox(height: 12.dp),
          Align(
            alignment: Alignment.centerRight,
            child: _bubble(
              context,
              text: 'onb1_msg_out'.tr,
              bg: c.accent,
              textColor: c.onAccent,
            ),
          ),
          SizedBox(height: 8.dp),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 13.dp, color: c.textSecondary),
                SizedBox(width: 5.dp),
                Text(
                  'onb1_translated'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context,
      {required String text,
      required Color bg,
      required Color textColor,
      Color? border}) {
    return Container(
      constraints: BoxConstraints(maxWidth: 220.dp),
      padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18.dp),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 15.sp, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 2-slayd: yonma-yon jonli tarjima (ikki avatar + ovoz to'lqini).
class OnbLiveIllustration extends StatelessWidget {
  const OnbLiveIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return _OnbCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatar(context, accent: true),
              SizedBox(width: 18.dp),
              _wave(context),
              SizedBox(width: 18.dp),
              _avatar(context, accent: false),
            ],
          ),
          SizedBox(height: 22.dp),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 10.dp),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(30.dp),
              border: Border.all(color: c.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_none, size: 16.dp, color: c.accent),
                SizedBox(width: 8.dp),
                Text(
                  'onb2_badge'.tr,
                  style: TextStyle(color: c.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, {required bool accent}) {
    final c = context.appColors;
    final color = accent ? c.accent : c.textSecondary;
    return Container(
      width: 58.dp,
      height: 58.dp,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
        color: c.surface,
      ),
      child: Icon(Icons.person_outline, color: color, size: 28.dp),
    );
  }

  Widget _wave(BuildContext context) {
    final c = context.appColors;
    final heights = [10.0, 20.0, 32.0, 22.0, 12.0, 26.0, 16.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final h in heights)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.dp),
            child: Container(
              width: 4.dp,
              height: h.dp,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(4.dp),
              ),
            ),
          ),
      ],
    );
  }
}

/// 3-slayd: biznes — mahsulot kartalari (narxlar bilan).
class OnbBusinessIllustration extends StatelessWidget {
  const OnbBusinessIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final prices = ['\$120', '\$89', '\$240', '\$55'];
    return _OnbCard(
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12.dp,
        crossAxisSpacing: 12.dp,
        childAspectRatio: 1.5,
        children: [for (final p in prices) _card(context, p)],
      ),
    );
  }

  Widget _card(BuildContext context, String price) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.all(12.dp),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4.dp,
            width: 46.dp,
            decoration: BoxDecoration(
              color: c.textFaint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4.dp),
            ),
          ),
          SizedBox(height: 8.dp),
          Text(
            price,
            style: TextStyle(color: c.accent, fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
