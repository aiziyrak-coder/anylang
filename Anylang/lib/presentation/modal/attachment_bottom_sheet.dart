import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/chat/chat_action.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Biriktirish menyusi — "+" bosilganda pastdan chiqadi.
/// Grid: Galereya, Kamera, Fayl, (biznes) Mahsulot, Joylashuv, Kontakt.
/// Tanlangan/highlight holat yo‘q — faqat ripple + action.
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
          kind: AttachKind.gallery,
          icon: Icons.image_outlined,
          title: 'chat_attach_gallery'.tr,
        ),
        _AttachItem(
          kind: AttachKind.camera,
          icon: Icons.photo_camera_outlined,
          title: 'chat_attach_camera'.tr,
        ),
        _AttachItem(
          kind: AttachKind.file,
          icon: Icons.insert_drive_file_outlined,
          title: 'chat_attach_file'.tr,
        ),
        if (showProduct)
          _AttachItem(
            kind: AttachKind.product,
            icon: Icons.shopping_bag_outlined,
            title: 'chat_attach_product'.tr,
          ),
        _AttachItem(
          kind: AttachKind.location,
          icon: Icons.location_on_outlined,
          title: 'chat_attach_location'.tr,
        ),
        _AttachItem(
          kind: AttachKind.contact,
          icon: Icons.person_outline_rounded,
          title: 'chat_attach_contact'.tr,
        ),
      ];

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xFF0C2136) : c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.dp),
              Container(
                width: 40.dp,
                height: 4.dp,
                decoration: BoxDecoration(
                  color: c.outline.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2.dp),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.dp, 20.dp, 16.dp, 24.dp),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16.dp,
                    crossAxisSpacing: 12.dp,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _AttachTile(
                      item: item,
                      onTap: () => Navigator.pop(ctx, item.kind),
                    );
                  },
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

  const _AttachItem({
    required this.kind,
    required this.icon,
    required this.title,
  });
}

class _AttachTile extends StatelessWidget {
  final _AttachItem item;
  final VoidCallback onTap;

  const _AttachTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.dp),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64.dp,
                height: 64.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: c.surfaceBorder, width: 1),
                ),
                child: Icon(
                  item.icon,
                  size: 28.dp,
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}