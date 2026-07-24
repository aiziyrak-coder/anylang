import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

enum NewChatMenuAction { chat, group }

/// Xabarlar "+" tugmasi — xabar/suhbat menyusi uslubidagi oynacha.
Future<NewChatMenuAction?> showNewChatActionsDialog(
  BuildContext context, {
  required Rect anchor,
}) {
  return showGeneralDialog<NewChatMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'messages_new_chat'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) =>
        _NewChatActionsOverlay(anchor: anchor),
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

class _NewChatActionsOverlay extends StatelessWidget {
  final Rect anchor;

  const _NewChatActionsOverlay({required this.anchor});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final screen = MediaQuery.of(context).size;

    const menuWidth = 260.0;
    final menuHeight = 2 * 48.dp + 16.dp;
    const gap = 8.0;
    const edgeMargin = 14.0;

    double menuLeft = anchor.right - menuWidth;
    menuLeft = menuLeft.clamp(edgeMargin, screen.width - menuWidth - edgeMargin);

    final menuTop = (anchor.bottom + gap)
        .clamp(edgeMargin, screen.height - menuHeight - edgeMargin);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Positioned(
              left: menuLeft,
              top: menuTop,
              width: menuWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
                  borderRadius: BorderRadius.circular(16.dp),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: c.isDark ? 0.45 : 0.18),
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
                      c,
                      Icons.person_add_alt_1_rounded,
                      'messages_new_chat'.tr,
                      NewChatMenuAction.chat,
                    ),
                    _row(
                      context,
                      c,
                      Icons.groups_rounded,
                      'messages_new_group'.tr,
                      NewChatMenuAction.group,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext ctx,
    AppColors c,
    IconData icon,
    String label,
    NewChatMenuAction action,
  ) {
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
              Icon(icon, color: c.textPrimary, size: 20.dp),
              SizedBox(width: 12.dp),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
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
