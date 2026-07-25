import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/screen_options/my_action.dart';
import '../utils/size_controller.dart';
import '../screens/profile/profile_action.dart';

/// Sofiya AI — savol / muammo / maslahat tanlash.
Future<void> showSofiyaAiBottomSheet(
  BuildContext context, {
  required void Function(MyAction) sendAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SofiyaAiSheet(sendAction: sendAction),
  );
}

class _SofiyaAiSheet extends StatelessWidget {
  final void Function(MyAction) sendAction;

  const _SofiyaAiSheet({required this.sendAction});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final items = [
      (Icons.chat_bubble_outline_rounded, 'profile_sofiya_ask'.tr),
      (Icons.build_circle_outlined, 'profile_sofiya_fix'.tr),
      (Icons.lightbulb_outline_rounded, 'profile_sofiya_tips'.tr),
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
              Row(
                children: [
                  Container(
                    width: 44.dp,
                    height: 44.dp,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(14.dp),
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: c.accentText,
                      size: 24.dp,
                    ),
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'profile_sofiya_title'.tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2.dp),
                        Text(
                          'profile_sofiya_desc'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.dp),
              for (final item in items) ...[
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14.dp),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      sendAction(OpenSupportFromProfile());
                    },
                    borderRadius: BorderRadius.circular(14.dp),
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.dp,
                        vertical: 14.dp,
                      ),
                      decoration: BoxDecoration(
                        color: c.isDark
                            ? const Color(0x99152A42)
                            : const Color(0xCCFFFFFF),
                        borderRadius: BorderRadius.circular(14.dp),
                        border: Border.all(color: c.surfaceBorder, width: 0.7),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$1, color: c.accentText, size: 22.dp),
                          SizedBox(width: 12.dp),
                          Expanded(
                            child: Text(
                              item.$2,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: c.textFaint,
                            size: 22.dp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.dp),
              ],
              PrimaryButton(
                text: 'profile_sofiya_chat'.tr,
                onTap: () {
                  Navigator.pop(context);
                  sendAction(OpenSupportFromProfile());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
