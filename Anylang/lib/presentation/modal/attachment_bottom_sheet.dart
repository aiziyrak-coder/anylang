import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/chat/chat_action.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Biriktirish menyusi — "+" bosilganda pastdan chiqadi.
/// Faqat: Rasm, Fayl, (biznes) Mahsulot, Joylashuv, Kontakt.
Future<AttachKind?> showAttachmentBottomSheet(
  BuildContext context, {
  bool showProduct = false,
}) {
  final c = context.appColors;
  return showModalBottomSheet<AttachKind>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
      final items = <_AttachItem>[
        _AttachItem(
          kind: AttachKind.photo,
          icon: Icons.photo_outlined,
          title: 'chat_attach_photo'.tr,
          subtitle: 'chat_attach_photo_hint'.tr,
          tint: c.accent,
        ),
        _AttachItem(
          kind: AttachKind.file,
          icon: Icons.insert_drive_file_outlined,
          title: 'chat_attach_file'.tr,
          subtitle: 'chat_attach_file_hint'.tr,
          tint: c.accentText,
        ),
        if (showProduct)
          _AttachItem(
            kind: AttachKind.product,
            icon: Icons.storefront_outlined,
            title: 'chat_attach_product'.tr,
            subtitle: 'chat_attach_product_hint'.tr,
            tint: c.accent,
          ),
        _AttachItem(
          kind: AttachKind.location,
          icon: Icons.location_on_outlined,
          title: 'chat_attach_location'.tr,
          subtitle: 'chat_attach_location_hint'.tr,
          tint: kListenRed,
        ),
        _AttachItem(
          kind: AttachKind.contact,
          icon: Icons.person_outline_rounded,
          title: 'chat_attach_contact'.tr,
          subtitle: 'chat_attach_contact_hint'.tr,
          tint: c.accentText,
        ),
      ];

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xFF0C2136) : c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.dp)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40.dp,
                      height: 4.dp,
                      decoration: BoxDecoration(
                        color: c.outline.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2.dp),
                      ),
                    ),
                    SizedBox(height: 16.dp),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'chat_attach_title'.tr,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'chat_attach_subtitle'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13.sp,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.dp),
              Padding(
                padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 20.dp),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : c.background.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20.dp),
                    border: Border.all(
                      color: c.surfaceBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _AttachRow(
                          item: items[i],
                          onTap: () => Navigator.pop(ctx, items[i].kind),
                        ),
                        if (i < items.length - 1)
                          Padding(
                            padding: EdgeInsets.only(left: 72.dp),
                            child: Divider(
                              height: 1,
                              thickness: 0.7,
                              color: c.surfaceBorder.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ],
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

class _AttachItem {
  final AttachKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;

  const _AttachItem({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });
}

class _AttachRow extends StatelessWidget {
  final _AttachItem item;
  final VoidCallback onTap;

  const _AttachRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
          child: Row(
            children: [
              Container(
                width: 48.dp,
                height: 48.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.tint.withValues(alpha: c.isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(14.dp),
                ),
                child: Icon(item.icon, size: 24.dp, color: item.tint),
              ),
              SizedBox(width: 14.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.dp),
              Icon(
                Icons.chevron_right_rounded,
                size: 22.dp,
                color: c.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
