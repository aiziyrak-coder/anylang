import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/screen_options/my_action.dart';
import '../utils/size_controller.dart';
import '../screens/profile/profile_action.dart';

/// BUSINESS badge — Premium afzalliklari sheet.
Future<void> showBusinessBenefitsBottomSheet(
  BuildContext context, {
  required void Function(MyAction) sendAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BusinessBenefitsSheet(sendAction: sendAction),
  );
}

class _BusinessBenefitsSheet extends StatelessWidget {
  final void Function(MyAction) sendAction;

  const _BusinessBenefitsSheet({required this.sendAction});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final items = [
      (Icons.workspace_premium_rounded, 'profile_biz_benefit_premium'.tr),
      (Icons.verified_rounded, 'profile_biz_benefit_verified'.tr),
      (Icons.insights_rounded, 'profile_biz_benefit_analytics'.tr),
      (Icons.campaign_rounded, 'profile_biz_benefit_ads'.tr),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(2.dp),
                  ),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                'profile_business_benefits_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'profile_business_benefits_desc'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 16.dp),
              for (final item in items) ...[
                _row(c, item.$1, item.$2),
                SizedBox(height: 10.dp),
              ],
              SizedBox(height: 8.dp),
              PrimaryButton(
                text: 'profile_business_cta'.tr,
                onTap: () {
                  Navigator.pop(context);
                  sendAction(OpenBusinessAccount());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(AppColors c, IconData icon, String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 12.dp),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
      ),
      child: Row(
        children: [
          Container(
            width: 38.dp,
            height: 38.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(12.dp),
            ),
            child: Icon(icon, color: c.accentText, size: 20.dp),
          ),
          SizedBox(width: 12.dp),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
