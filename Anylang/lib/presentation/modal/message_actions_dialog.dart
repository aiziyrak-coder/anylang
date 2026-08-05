import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../screens/chat/chat_message.dart';
import '../ui/items/chat_message_item.dart';
import '../ui/theme/colors.dart';
import '../utils/business_reactions.dart';
import '../utils/size_controller.dart';
import 'telegram_action_sheet.dart';

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

/// Menyudan qaytadigan natija (o‘chirish scope bilan).
class MessageMenuResult {
  final MessageMenuAction action;
  final bool? deleteForEveryone;

  const MessageMenuResult(this.action, {this.deleteForEveryone});
}

/// Uzoq bosish menyusi: biznes reaksiyalar + amallar.
Future<MessageMenuResult?> showMessageActionsDialog(
  BuildContext context, {
  required ChatMessage message,
  required Rect anchor,
  bool isGroup = false,
  bool showSenderName = false,
  bool showAvatar = false,
  bool showTranslate = false,
  bool canPin = true,
  bool canDeleteForEveryone = false,
  void Function(String emoji)? onReact,
}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context, rootNavigator: true).push<MessageMenuResult>(
    _MessageActionsRoute(
      message: message,
      anchor: anchor,
      isGroup: isGroup,
      showSenderName: showSenderName,
      showAvatar: showAvatar,
      showTranslate: showTranslate,
      canPin: canPin,
      canDeleteForEveryone: canDeleteForEveryone,
      onReact: onReact,
    ),
  );
}

class _MessageActionsRoute extends PopupRoute<MessageMenuResult> {
  final ChatMessage message;
  final Rect anchor;
  final bool isGroup;
  final bool showSenderName;
  final bool showAvatar;
  final bool showTranslate;
  final bool canPin;
  final bool canDeleteForEveryone;
  final void Function(String emoji)? onReact;

  _MessageActionsRoute({
    required this.message,
    required this.anchor,
    required this.isGroup,
    required this.showSenderName,
    required this.showAvatar,
    required this.showTranslate,
    required this.canPin,
    required this.canDeleteForEveryone,
    this.onReact,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'chat_menu_original'.tr;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _MessageActionsOverlay(
      animation: animation,
      message: message,
      anchor: anchor,
      isGroup: isGroup,
      showSenderName: showSenderName,
      showAvatar: showAvatar,
      showTranslate: showTranslate,
      canPin: canPin,
      canDeleteForEveryone: canDeleteForEveryone,
      onReact: onReact,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Overlay o‘zi animation’ni qatlamlab boshqaradi — qo‘shimcha fade yo‘q.
    return child;
  }
}

class _MessageActionsOverlay extends StatelessWidget {
  final Animation<double> animation;
  final ChatMessage message;
  final Rect anchor;
  final bool isGroup;
  final bool showSenderName;
  final bool showAvatar;
  final bool showTranslate;
  final bool canPin;
  final bool canDeleteForEveryone;
  final void Function(String emoji)? onReact;

  const _MessageActionsOverlay({
    required this.animation,
    required this.message,
    required this.anchor,
    required this.isGroup,
    required this.showSenderName,
    required this.showAvatar,
    required this.showTranslate,
    required this.canPin,
    required this.canDeleteForEveryone,
    this.onReact,
  });

  bool get _out => message.isOutgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final showReceipt = _out && message.status == ChatStatus.read;

    final showProfile = isGroup && !_out && (message.senderId ?? 0) > 0;
    const menuWidth = 288.0;
    final rows = 5 +
        (showTranslate ? 1 : 0) +
        (canPin ? 1 : 0) +
        (showProfile ? 1 : 0) +
        (message.type == ChatMsgType.text && _out ? 1 : 0);
    final menuHeight = rows * 44.dp + 118.dp;
    const gap = 10.0;
    const chipHeight = 34.0;
    final edgeMargin = 14.0;
    final topSafe = padding.top + edgeMargin;
    final bottomSafe = screen.height - padding.bottom - edgeMargin;

    double menuLeft = _out ? anchor.right - menuWidth : anchor.left;
    menuLeft = menuLeft.clamp(edgeMargin, screen.width - menuWidth - edgeMargin);

    final spaceBelow = bottomSafe - anchor.bottom;
    final spaceAbove = anchor.top - topSafe;
    final showMenuBelow =
        spaceBelow >= menuHeight + gap || spaceBelow >= spaceAbove;
    final menuTop = showMenuBelow
        ? (anchor.bottom + gap).clamp(topSafe, bottomSafe - menuHeight)
        : (anchor.top - gap - menuHeight).clamp(topSafe, bottomSafe - menuHeight);

    final chipTop = anchor.top - gap - chipHeight;
    double chipLeft = _out ? anchor.right - 160 : anchor.left;
    chipLeft = chipLeft.clamp(edgeMargin, screen.width - 160 - edgeMargin);

    final msgLeft = anchor.left.clamp(0.0, screen.width);
    final msgTop = anchor.top.clamp(0.0, screen.height);
    final msgWidth = anchor.width.clamp(0.0, screen.width - msgLeft);

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final barrierOpacity = Tween<double>(begin: 0, end: 0.55).animate(curved);
    final menuFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.08, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final menuScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.05, 1, curve: Curves.easeOutCubic),
        reverseCurve: Curves.easeInCubic,
      ),
    );
    final chipFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Barrier — alohida fade (xabar opacity o‘zgarmaydi → jank kamayadi).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: AnimatedBuilder(
                animation: barrierOpacity,
                builder: (_, _) => ColoredBox(
                  color: Colors.black.withValues(alpha: barrierOpacity.value),
                ),
              ),
            ),
          ),
          Positioned(
            left: msgLeft,
            top: msgTop,
            width: msgWidth,
            child: RepaintBoundary(
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
          ),
          if (showReceipt && chipTop > topSafe)
            Positioned(
              left: chipLeft,
              top: chipTop,
              child: FadeTransition(
                opacity: chipFade,
                child: _ReadReceiptChip(time: message.time),
              ),
            ),
          Positioned(
            left: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: FadeTransition(
              opacity: menuFade,
              child: ScaleTransition(
                scale: menuScale,
                alignment:
                    showMenuBelow ? Alignment.topCenter : Alignment.bottomCenter,
                child: RepaintBoundary(
                  child: _MenuCard(
                    c: c,
                    message: message,
                    showTranslate: showTranslate,
                    showProfile: showProfile,
                    canPin: canPin,
                    canDeleteForEveryone: canDeleteForEveryone,
                    onReact: onReact,
                  ),
                ),
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
  final bool canDeleteForEveryone;
  final void Function(String emoji)? onReact;

  const _MenuCard({
    required this.c,
    required this.message,
    required this.showTranslate,
    required this.showProfile,
    required this.canPin,
    required this.canDeleteForEveryone,
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
            color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 6.dp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10.dp, 8.dp, 10.dp, 10.dp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'biz_react_title'.tr,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 8.dp),
                Wrap(
                  spacing: 6.dp,
                  runSpacing: 6.dp,
                  children: [
                    for (final r in kBusinessReactions)
                      Material(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(16.dp),
                        child: InkWell(
                          onTap: () {
                            onReact?.call(r.emoji);
                            Navigator.pop(
                              context,
                              const MessageMenuResult(MessageMenuAction.react),
                            );
                          },
                          borderRadius: BorderRadius.circular(16.dp),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.dp,
                              vertical: 7.dp,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.dp),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              r.chipText,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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

  Future<void> _onDelete(BuildContext ctx) async {
    final actions = <TelegramSheetAction>[
      if (canDeleteForEveryone)
        TelegramSheetAction(
          id: 'everyone',
          label: 'chat_msg_delete_everyone'.tr,
          danger: true,
        ),
      TelegramSheetAction(
        id: 'me',
        label: 'chat_msg_delete_me'.tr,
        danger: true,
      ),
    ];
    final choice = await showTelegramActionSheet(
      ctx,
      title: 'chat_msg_delete_title'.tr,
      body: 'chat_msg_delete_choose'.tr,
      actions: actions,
      // Menyuning o‘zi dim qilgan — qo‘shimcha scrim qotish bermasligi uchun.
      barrierColor: Colors.transparent,
    );
    if (!ctx.mounted || choice == null) return;
    final result = MessageMenuResult(
      MessageMenuAction.delete,
      deleteForEveryone: choice == 'everyone',
    );
    // Sheet pop bilan bir frame ichida menyuni ham yopamiz (stack tartibi saqlanadi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctx.mounted) Navigator.pop(ctx, result);
    });
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
        onTap: () {
          if (action == MessageMenuAction.delete) {
            _onDelete(ctx);
            return;
          }
          Navigator.pop(ctx, MessageMenuResult(action));
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
