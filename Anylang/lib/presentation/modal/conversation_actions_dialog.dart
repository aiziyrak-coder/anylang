import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/messages/conversation.dart';
import '../ui/items/conversation_item.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';
import 'chat_overflow_sheet.dart';

/// Suhbatdosh item long-press: xabar menyusi uslubidagi oynacha.
/// Bottom sheet amallari (qidiruvsiz).
Future<ChatOverflowAction?> showConversationActionsDialog(
  BuildContext context, {
  required Conversation conversation,
  required Rect anchor,
  required bool muted,
}) {
  return showGeneralDialog<ChatOverflowAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'chat_overflow_delete_chat'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) =>
        _ConversationActionsOverlay(
      conversation: conversation,
      anchor: anchor,
      muted: muted,
    ),
    transitionBuilder: (ctx, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}

class _ConversationActionsOverlay extends StatelessWidget {
  final Conversation conversation;
  final Rect anchor;
  final bool muted;

  const _ConversationActionsOverlay({
    required this.conversation,
    required this.anchor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final screen = MediaQuery.of(context).size;

    const menuWidth = 260.0;
    final rows = conversation.isGroup ? 5 : 6; // pin, mute, profile/settings, clear, delete, (+block DM)
    final menuHeight = rows * 48.dp + 20.dp;
    const gap = 10.0;
    const edgeMargin = 14.0;

    double menuLeft = (anchor.left + anchor.width / 2) - menuWidth / 2;
    menuLeft = menuLeft.clamp(edgeMargin, screen.width - menuWidth - edgeMargin);

    final spaceBelow = screen.height - anchor.bottom;
    final showMenuBelow = spaceBelow >= menuHeight + gap + 40;
    final menuTop = showMenuBelow
        ? anchor.bottom + gap
        : (anchor.top - gap - menuHeight).clamp(edgeMargin, screen.height - menuHeight - edgeMargin);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Positioned(
              left: anchor.left,
              top: anchor.top,
              width: anchor.width,
              child: IgnorePointer(
                child: ConversationItem(
                  initial: conversation.initial,
                  avatarGradient: conversation.avatarGradient,
                  initialColor: conversation.initialColor,
                  name: conversation.name,
                  lastMessage: conversation.lastMessage,
                  time: conversation.time,
                  online: conversation.online,
                  unread: conversation.unread,
                  highlighted: true,
                  muted: muted,
                  pinned: conversation.pinned,
                  isGroup: conversation.isGroup,
                  avatarUrl: conversation.avatarUrl,
                  onTap: () {},
                ),
              ),
            ),
            Positioned(
              left: menuLeft,
              top: menuTop,
              width: menuWidth,
              child: _MenuCard(
                c: c,
                muted: muted,
                pinned: conversation.pinned,
                isGroup: conversation.isGroup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final AppColors c;
  final bool muted;
  final bool pinned;
  final bool isGroup;

  const _MenuCard({
    required this.c,
    required this.muted,
    required this.pinned,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.circular(16.dp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 6.dp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
            context,
            muted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            muted ? 'chat_overflow_unmute'.tr : 'chat_overflow_mute'.tr,
            ChatOverflowAction.mute,
          ),
          _row(
            context,
            pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            pinned ? 'chat_overflow_unpin'.tr : 'chat_overflow_pin'.tr,
            ChatOverflowAction.pin,
          ),
          if (!isGroup)
            _row(
              context,
              Icons.person_outline_rounded,
              'chat_overflow_profile'.tr,
              ChatOverflowAction.profile,
            ),
          if (isGroup)
            _row(
              context,
              Icons.groups_outlined,
              'chat_overflow_group_settings'.tr,
              ChatOverflowAction.groupSettings,
            ),
          Divider(height: 12.dp, color: c.outline),
          _row(
            context,
            Icons.history_rounded,
            'chat_overflow_clear'.tr,
            ChatOverflowAction.clearHistory,
          ),
          _row(
            context,
            Icons.delete_outline_rounded,
            'chat_overflow_delete_chat'.tr,
            ChatOverflowAction.deleteChat,
            danger: true,
          ),
          if (!isGroup)
            _row(
              context,
              Icons.block_rounded,
              'chat_overflow_block'.tr,
              ChatOverflowAction.block,
              danger: true,
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext ctx,
    IconData icon,
    String label,
    ChatOverflowAction action, {
    bool danger = false,
  }) {
    final fg = danger ? const Color(0xFFB42318) : c.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 120));
          if (ctx.mounted) Navigator.pop(ctx, action);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20.dp),
              SizedBox(width: 12.dp),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
