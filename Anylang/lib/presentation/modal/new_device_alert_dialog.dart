import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/buttons/secondary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Sofiya: yangi qurilma ulandi — ogohlantirish.
Future<bool?> showNewDeviceAlertDialog(
  BuildContext context, {
  required String deviceName,
  VoidCallback? onOpenDevices,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final c = ctx.appColors;
      return AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.dp),
          side: BorderSide(color: c.surfaceBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: c.accentText, size: 24.dp),
            SizedBox(width: 8.dp),
            Expanded(
              child: Text(
                'support_agent_name'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'devices_sofiya_new_title'.trParams({'device': deviceName}),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            SizedBox(height: 10.dp),
            Text(
              'devices_sofiya_new_body'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(20.dp, 0, 20.dp, 16.dp),
        actions: [
          PrimaryButton(
            text: 'devices_check_sessions'.tr,
            onTap: () {
              Navigator.pop(ctx, true);
              onOpenDevices?.call();
            },
          ),
          SizedBox(height: 8.dp),
          SecondaryButton(
            text: 'devices_its_me'.tr,
            onTap: () => Navigator.pop(ctx, false),
          ),
        ],
      );
    },
  );
}
