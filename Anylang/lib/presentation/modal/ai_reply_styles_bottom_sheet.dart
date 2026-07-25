import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/chat_ai_reply_styles.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Composer AI tugmasidan — uslub tanlash.
Future<String?> showAiReplyStylesBottomSheet(BuildContext context) {
  final c = context.appColors;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 20.dp),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2.dp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Text(
                'ai_reply_styles_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'ai_reply_styles_hint'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
              ),
              SizedBox(height: 16.dp),
              ChatAiReplyStyles(
                onSelect: (tone) => Navigator.pop(ctx, tone),
              ),
            ],
          ),
        ),
      );
    },
  );
}
