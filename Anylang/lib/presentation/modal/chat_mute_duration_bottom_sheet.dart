import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Suhbat mute muddati (Telegram uslubi).
enum ChatMuteDuration {
  oneHour,
  threeHours,
  oneDay,
  forever,
}

extension ChatMuteDurationX on ChatMuteDuration {
  Duration? get asDuration => switch (this) {
        ChatMuteDuration.oneHour => const Duration(hours: 1),
        ChatMuteDuration.threeHours => const Duration(hours: 3),
        ChatMuteDuration.oneDay => const Duration(days: 1),
        ChatMuteDuration.forever => null,
      };

  int? get durationSeconds => asDuration?.inSeconds;

  String get labelKey => switch (this) {
        ChatMuteDuration.oneHour => 'chat_mute_1h',
        ChatMuteDuration.threeHours => 'chat_mute_3h',
        ChatMuteDuration.oneDay => 'chat_mute_1d',
        ChatMuteDuration.forever => 'chat_mute_forever',
      };

  String get toastKey => switch (this) {
        ChatMuteDuration.oneHour => 'chat_muted_1h',
        ChatMuteDuration.threeHours => 'chat_muted_3h',
        ChatMuteDuration.oneDay => 'chat_muted_1d',
        ChatMuteDuration.forever => 'chat_muted',
      };
}

/// Mute muddatini tanlash bottom sheet.
Future<ChatMuteDuration?> showChatMuteDurationBottomSheet(
  BuildContext context,
) {
  final c = context.appColors;
  return showModalBottomSheet<ChatMuteDuration>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.dp,
                  height: 5.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(5.dp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Text(
                'chat_mute_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'chat_mute_subtitle'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18.dp),
              Row(
                children: [
                  for (final d in [
                    ChatMuteDuration.oneHour,
                    ChatMuteDuration.threeHours,
                    ChatMuteDuration.oneDay,
                    ChatMuteDuration.forever,
                  ]) ...[
                    if (d != ChatMuteDuration.oneHour) SizedBox(width: 8.dp),
                    Expanded(
                      child: _MuteDurationTile(
                        c: c,
                        duration: d,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx, d);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 12.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14.dp),
                  onTap: () => Navigator.pop(ctx),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.dp),
                    child: Text(
                      'cancel'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MuteDurationTile extends StatelessWidget {
  final AppColors c;
  final ChatMuteDuration duration;
  final VoidCallback onTap;

  const _MuteDurationTile({
    required this.c,
    required this.duration,
    required this.onTap,
  });

  IconData get _icon => switch (duration) {
        ChatMuteDuration.oneHour => Icons.schedule_rounded,
        ChatMuteDuration.threeHours => Icons.timelapse_rounded,
        ChatMuteDuration.oneDay => Icons.today_rounded,
        ChatMuteDuration.forever => Icons.notifications_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16.dp);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 6.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: c.textPrimary, size: 26.dp),
              SizedBox(height: 8.dp),
              Text(
                duration.labelKey.tr,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
