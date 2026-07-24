import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Chat app bar ⋮ menyusi natijasi (Telegram uslubi).
enum ChatOverflowAction {
  profile,
  groupSettings,
  search,
  mute,
  pin,
  clearHistory,
  deleteChat,
  block,
}

/// Yuqori o‘ng ⋮ tugmasidan ochiladigan suhbat menyusi.
Future<ChatOverflowAction?> showChatOverflowSheet(
  BuildContext context, {
  required bool muted,
  bool pinned = false,
  bool isGroup = false,
}) {
  final c = context.appColors;
  return showModalBottomSheet<ChatOverflowAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(8.dp, 12.dp, 8.dp, 20.dp),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.dp,
                height: 5.dp,
                decoration: BoxDecoration(
                  color: c.outline,
                  borderRadius: BorderRadius.circular(5.dp),
                ),
              ),
              SizedBox(height: 10.dp),
              _item(
                ctx,
                c,
                muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                muted
                    ? 'chat_overflow_unmute'.tr
                    : 'chat_overflow_mute'.tr,
                ChatOverflowAction.mute,
              ),
              _item(
                ctx,
                c,
                pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                pinned
                    ? 'chat_overflow_unpin'.tr
                    : 'chat_overflow_pin'.tr,
                ChatOverflowAction.pin,
              ),
              if (!isGroup)
                _item(
                  ctx,
                  c,
                  Icons.person_outline_rounded,
                  'chat_overflow_profile'.tr,
                  ChatOverflowAction.profile,
                ),
              if (isGroup)
                _item(
                  ctx,
                  c,
                  Icons.groups_outlined,
                  'chat_overflow_group_settings'.tr,
                  ChatOverflowAction.groupSettings,
                ),
              Divider(height: 16.dp, color: c.outline),
              _item(
                ctx,
                c,
                Icons.history_rounded,
                'chat_overflow_clear'.tr,
                ChatOverflowAction.clearHistory,
              ),
              _item(
                ctx,
                c,
                Icons.delete_outline_rounded,
                'chat_overflow_delete_chat'.tr,
                ChatOverflowAction.deleteChat,
                danger: true,
              ),
              if (!isGroup)
                _item(
                  ctx,
                  c,
                  Icons.block_rounded,
                  'chat_overflow_block'.tr,
                  ChatOverflowAction.block,
                  danger: true,
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _item(
  BuildContext ctx,
  AppColors c,
  IconData icon,
  String label,
  ChatOverflowAction action, {
  bool danger = false,
}) {
  final color = danger ? const Color(0xFFB42318) : c.textPrimary;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => Navigator.pop(ctx, action),
      borderRadius: BorderRadius.circular(14.dp),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22.dp),
            SizedBox(width: 14.dp),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
