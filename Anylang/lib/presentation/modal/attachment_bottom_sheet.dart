import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/chat/chat_action.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Biriktirish menyusi (3b) — "+" bosilganda pastdan chiqadi.
Future<AttachKind?> showAttachmentBottomSheet(BuildContext context) {
  final c = context.appColors;
  return showModalBottomSheet<AttachKind>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      // viewPadding — Android gesture/nav bar; SafeArea ba'zan sheet ichida 0 qaytaradi.
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
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
              SizedBox(height: 20.dp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tile(ctx, c, AttachKind.gallery, Icons.photo_library_outlined,
                      'chat_attach_gallery'.tr),
                  _tile(ctx, c, AttachKind.camera, Icons.photo_camera_outlined,
                      'chat_attach_camera'.tr),
                  _tile(ctx, c, AttachKind.file, Icons.insert_drive_file_outlined,
                      'chat_attach_file'.tr),
                ],
              ),
              SizedBox(height: 18.dp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tile(ctx, c, AttachKind.product, Icons.sell_outlined,
                      'chat_attach_product'.tr),
                  _tile(ctx, c, AttachKind.location, Icons.location_on_outlined,
                      'chat_attach_location'.tr),
                  _tile(ctx, c, AttachKind.contact, Icons.person_outline,
                      'chat_attach_contact'.tr),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile(
  BuildContext ctx,
  AppColors c,
  AttachKind kind,
  IconData icon,
  String label,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(ctx, kind),
          borderRadius: BorderRadius.circular(18.dp),
          child: Container(
            width: 68.dp,
            height: 68.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.surfaceBorder),
              borderRadius: BorderRadius.circular(18.dp),
            ),
            child: Icon(icon, size: 26.dp, color: c.accentText),
          ),
        ),
      ),
      SizedBox(height: 8.dp),
      Text(
        label,
        style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
      ),
    ],
  );
}
