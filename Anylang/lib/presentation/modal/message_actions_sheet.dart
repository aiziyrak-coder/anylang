import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Xabar kontekst menyusi (3c) natijasi.
enum MessageMenuAction { translate, reply, copy, delete }

/// Xabar ustiga uzoq bosilganda ochiladigan menyu (3c). Tanlangan action'ni
/// qaytaradi. `showTranslate` — faqat tarjima qilingan matnli xabarlar uchun
/// "asl nusxa" qatorini ko'rsatadi.
Future<MessageMenuAction?> showMessageActionsSheet(
  BuildContext context, {
  bool showTranslate = false,
}) {
  final c = context.appColors;
  return showModalBottomSheet<MessageMenuAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(12.dp, 12.dp, 12.dp, 20.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.dp,
              height: 5.dp,
              margin: EdgeInsets.only(bottom: 8.dp),
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(5.dp),
              ),
            ),
            if (showTranslate)
              _row(
                ctx,
                c,
                MessageMenuAction.translate,
                Icons.language_rounded,
                'chat_menu_original'.tr,
                color: c.accentText,
              ),
            _row(
              ctx,
              c,
              MessageMenuAction.reply,
              Icons.reply_rounded,
              'chat_menu_reply'.tr,
            ),
            _row(
              ctx,
              c,
              MessageMenuAction.copy,
              Icons.copy_rounded,
              'chat_menu_copy'.tr,
            ),
            _row(
              ctx,
              c,
              MessageMenuAction.delete,
              Icons.delete_outline_rounded,
              'chat_menu_delete'.tr,
              color: kListenRed,
            ),
          ],
        ),
      );
    },
  );
}

Widget _row(
  BuildContext ctx,
  AppColors c,
  MessageMenuAction action,
  IconData icon,
  String label, {
  Color? color,
}) {
  final fg = color ?? c.textPrimary;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => Navigator.pop(ctx, action),
      borderRadius: BorderRadius.circular(12.dp),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 14.dp),
        child: Row(
          children: [
            Icon(icon, size: 20.dp, color: fg),
            SizedBox(width: 14.dp),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
