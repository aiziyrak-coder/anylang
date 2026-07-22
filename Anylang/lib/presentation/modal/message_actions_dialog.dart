import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../screens/chat/chat_message.dart';
import '../ui/items/chat_message_item.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Xabar kontekst menyusi (3c — dark, 3g — light) natijasi.
enum MessageMenuAction { translate, reply, copy, delete }

/// Xabar ustiga uzoq bosilganda ochiladigan, bosilgan pufakchaga bog'langan
/// (anchored) menyu. Figma dizayniga mos: xabar nusxasi joyida qoladi, uning
/// ustida (chiquvchi va o'qilgan bo'lsa) o'qildi-belgisi chipi, ostida esa
/// harakatlar ro'yxati ko'rinadi. Tanlangan action'ni qaytaradi.
Future<MessageMenuAction?> showMessageActionsDialog(
  BuildContext context, {
  required ChatMessage message,
  required Rect anchor,
  bool showTranslate = false,
}) {
  return showGeneralDialog<MessageMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'chat_menu_original'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) => _MessageActionsOverlay(
      message: message,
      anchor: anchor,
      showTranslate: showTranslate,
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

class _MessageActionsOverlay extends StatelessWidget {
  final ChatMessage message;
  final Rect anchor;
  final bool showTranslate;

  const _MessageActionsOverlay({
    required this.message,
    required this.anchor,
    required this.showTranslate,
  });

  bool get _out => message.isOutgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final screen = MediaQuery.of(context).size;
    final showReceipt = _out && message.status == ChatStatus.read;

    const menuWidth = 240.0;
    final menuHeight = (showTranslate ? 4 : 3) * 48.dp + 20.dp;
    const gap = 10.0;
    const chipHeight = 34.0;
    const edgeMargin = 14.0;

    // Menyu bubble bilan bir tomonga (chiquvchi->o'ng, kiruvchi->chap) tekislanadi.
    double menuLeft = _out ? anchor.right - menuWidth : anchor.left;
    menuLeft = menuLeft.clamp(edgeMargin, screen.width - menuWidth - edgeMargin);

    final spaceBelow = screen.height - anchor.bottom;
    final showMenuBelow = spaceBelow >= menuHeight + gap + 40;
    final menuTop = showMenuBelow
        ? anchor.bottom + gap
        : (anchor.top - gap - menuHeight).clamp(edgeMargin, screen.height);

    final chipTop = anchor.top - gap - chipHeight;
    double chipLeft = _out ? anchor.right - 160 : anchor.left;
    chipLeft = chipLeft.clamp(edgeMargin, screen.width - 160 - edgeMargin);

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
                child: ChatMessageItem(message: message, onLongPress: () {}),
              ),
            ),
            if (showReceipt && chipTop > edgeMargin)
              Positioned(
                left: chipLeft,
                top: chipTop,
                child: _ReadReceiptChip(time: message.time),
              ),
            Positioned(
              left: menuLeft,
              top: menuTop,
              width: menuWidth,
              child: _MenuCard(
                c: c,
                showTranslate: showTranslate,
              ),
            ),
          ],
        ),
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
  final bool showTranslate;

  const _MenuCard({required this.c, required this.showTranslate});

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
          if (showTranslate)
            _row(
              context,
              MessageMenuAction.translate,
              'assets/icons/ic_globe.svg',
              'chat_menu_original'.tr,
              color: c.accentText,
            ),
          _row(
            context,
            MessageMenuAction.reply,
            'assets/icons/ic_chat_reply.svg',
            'chat_menu_reply'.tr,
          ),
          _row(
            context,
            MessageMenuAction.copy,
            'assets/icons/ic_copy.svg',
            'chat_menu_copy'.tr,
          ),
          _row(
            context,
            MessageMenuAction.delete,
            'assets/icons/ic_trash.svg',
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
    String iconAsset,
    String label, {
    Color? color,
  }) {
    final fg = color ?? c.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Ripple animatsiyasi to'liq ko'rinib ulgurishi uchun kichik pauza.
          await Future.delayed(const Duration(milliseconds: 150));
          if (ctx.mounted) Navigator.pop(ctx, action);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
          child: Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 18.dp,
                height: 18.dp,
                colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
              ),
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
