import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../screens/chat/chat_message.dart';
import '../ui/items/chat_message_item.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Xabar kontekst menyusi natijasi.
enum MessageMenuAction {
  translate,
  reply,
  copy,
  delete,
  edit,
  forward,
  pin,
  select,
  react,
  profile,
}

const kAllowedReactions = [
  '👍',
  '❤️',
  '😂',
  '🔥',
  '😢',
  '🎉',
  '🙏',
  '👏',
  '😍',
  '😮',
  '😡',
  '🤔',
  '💯',
  '👀',
  '🤝',
  '💪',
  '✨',
  '🥰',
];

/// Uzoq bosish menyusi: reaksiyalar + amallar.
Future<MessageMenuAction?> showMessageActionsDialog(
  BuildContext context, {
  required ChatMessage message,
  required Rect anchor,
  bool isGroup = false,
  bool showSenderName = false,
  bool showAvatar = false,
  bool showTranslate = false,
  bool canPin = true,
  void Function(String emoji)? onReact,
}) {
  return showGeneralDialog<MessageMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'chat_menu_original'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, animation, secondaryAnimation) => _MessageActionsOverlay(
      message: message,
      anchor: anchor,
      isGroup: isGroup,
      showSenderName: showSenderName,
      showAvatar: showAvatar,
      showTranslate: showTranslate,
      canPin: canPin,
      onReact: onReact,
    ),
    // Faqat fade — Scale butun overlay'ni markazga siljitib,
    // bosilgan xabarni joyidan chiqarib yuboradi.
    transitionBuilder: (ctx, animation, _, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

class _MessageActionsOverlay extends StatelessWidget {
  final ChatMessage message;
  final Rect anchor;
  final bool isGroup;
  final bool showSenderName;
  final bool showAvatar;
  final bool showTranslate;
  final bool canPin;
  final void Function(String emoji)? onReact;

  const _MessageActionsOverlay({
    required this.message,
    required this.anchor,
    required this.isGroup,
    required this.showSenderName,
    required this.showAvatar,
    required this.showTranslate,
    required this.canPin,
    this.onReact,
  });

  bool get _out => message.isOutgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.paddingOf(context);
    final showReceipt = _out && message.status == ChatStatus.read;

    final showProfile =
        isGroup && !_out && (message.senderId ?? 0) > 0;
    const menuWidth = 260.0;
    final rows = 5 +
        (showTranslate ? 1 : 0) +
        (canPin ? 1 : 0) +
        (showProfile ? 1 : 0) +
        (message.type == ChatMsgType.text && _out ? 1 : 0);
    final menuHeight = rows * 44.dp + 56.dp;
    const gap = 10.0;
    const chipHeight = 34.0;
    final edgeMargin = 14.0;
    final topSafe = padding.top + edgeMargin;
    final bottomSafe = screen.height - padding.bottom - edgeMargin;

    double menuLeft = _out ? anchor.right - menuWidth : anchor.left;
    menuLeft = menuLeft.clamp(edgeMargin, screen.width - menuWidth - edgeMargin);

    final spaceBelow = bottomSafe - anchor.bottom;
    final spaceAbove = anchor.top - topSafe;
    final showMenuBelow = spaceBelow >= menuHeight + gap || spaceBelow >= spaceAbove;
    final menuTop = showMenuBelow
        ? (anchor.bottom + gap).clamp(topSafe, bottomSafe - menuHeight)
        : (anchor.top - gap - menuHeight).clamp(topSafe, bottomSafe - menuHeight);

    final chipTop = anchor.top - gap - chipHeight;
    double chipLeft = _out ? anchor.right - 160 : anchor.left;
    chipLeft = chipLeft.clamp(edgeMargin, screen.width - 160 - edgeMargin);

    // Bosilgan item — aniq o'sha joyda (scale yo'q).
    final msgLeft = anchor.left.clamp(0.0, screen.width);
    final msgTop = anchor.top.clamp(0.0, screen.height);
    final msgWidth = anchor.width.clamp(0.0, screen.width - msgLeft);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: msgLeft,
            top: msgTop,
            width: msgWidth,
            child: IgnorePointer(
              child: ChatMessageItem(
                message: message,
                onLongPress: () {},
                isGroup: isGroup,
                showSenderName: showSenderName,
                showAvatar: showAvatar,
              ),
            ),
          ),
          if (showReceipt && chipTop > topSafe)
            Positioned(
              left: chipLeft,
              top: chipTop,
              child: _ReadReceiptChip(time: message.time),
            ),
          Positioned(
            left: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.96, end: 1),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: showMenuBelow ? Alignment.topCenter : Alignment.bottomCenter,
                child: child,
              ),
              child: _MenuCard(
                c: c,
                message: message,
                showTranslate: showTranslate,
                showProfile: showProfile,
                canPin: canPin,
                onReact: onReact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadReceiptChip extends StatelessWidget {
  final String time;
  const _ReadReceiptChip({required this.time});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 6.dp),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.surfaceBorder),
          borderRadius: BorderRadius.circular(14.dp),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/ic_check_double.svg',
              width: 14.dp,
              height: 14.dp,
              colorFilter: ColorFilter.mode(c.accentText, BlendMode.srcIn),
            ),
            SizedBox(width: 6.dp),
            Text(
              '${'chat_read_label'.tr} · ${'chat_today'.tr} $time',
              style: TextStyle(color: c.textSecondary, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final AppColors c;
  final ChatMessage message;
  final bool showTranslate;
  final bool showProfile;
  final bool canPin;
  final void Function(String emoji)? onReact;

  const _MenuCard({
    required this.c,
    required this.message,
    required this.showTranslate,
    required this.showProfile,
    required this.canPin,
    this.onReact,
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
          Padding(
            padding: EdgeInsets.fromLTRB(6.dp, 4.dp, 6.dp, 8.dp),
            child: SizedBox(
              height: 40.dp,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 4.dp),
                itemCount: kAllowedReactions.length,
                separatorBuilder: (_, __) => SizedBox(width: 2.dp),
                itemBuilder: (ctx, i) {
                  final emoji = kAllowedReactions[i];
                  return InkWell(
                    onTap: () {
                      onReact?.call(emoji);
                      Navigator.pop(ctx, MessageMenuAction.react);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 40.dp,
                      height: 40.dp,
                      child: Center(
                        child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Divider(height: 1, color: c.outline),
          if (showProfile)
            _row(
              context,
              MessageMenuAction.profile,
              Icons.person_outline_rounded,
              'chat_menu_profile'.tr,
            ),
          if (showTranslate)
            _row(
              context,
              MessageMenuAction.translate,
              Icons.translate_rounded,
              message.showingOriginal
                  ? 'chat_menu_translated'.tr
                  : 'chat_menu_original'.tr,
              color: c.accentText,
            ),
          _row(
            context,
            MessageMenuAction.reply,
            Icons.reply_rounded,
            'chat_menu_reply'.tr,
          ),
          if (message.type == ChatMsgType.text && message.isOutgoing)
            _row(
              context,
              MessageMenuAction.edit,
              Icons.edit_outlined,
              'chat_menu_edit'.tr,
            ),
          _row(
            context,
            MessageMenuAction.copy,
            Icons.content_copy_rounded,
            'chat_menu_copy'.tr,
          ),
          _row(
            context,
            MessageMenuAction.forward,
            Icons.shortcut_rounded,
            'chat_menu_forward'.tr,
          ),
          if (canPin)
            _row(
              context,
              MessageMenuAction.pin,
              message.pinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              message.pinned ? 'chat_menu_unpin'.tr : 'chat_menu_pin'.tr,
            ),
          _row(
            context,
            MessageMenuAction.select,
            Icons.check_circle_outline_rounded,
            'chat_menu_select'.tr,
          ),
          _row(
            context,
            MessageMenuAction.delete,
            Icons.delete_outline_rounded,
            'chat_menu_delete'.tr,
            color: kListenRed,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext ctx,
    MessageMenuAction action,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final fg = color ?? c.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 120));
          if (ctx.mounted) Navigator.pop(ctx, action);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 11.dp),
          child: Row(
            children: [
              Icon(icon, size: 20.dp, color: fg),
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
