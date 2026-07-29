import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';
import 'product.dart';

enum OwnProductAction {
  edit,
  boostTop,
  publish,
  unpublish,
  delete,
}

String formatTopCountdown(int? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) {
    return 'my_products_top_left_dh'.trParams({
      'days': '$d',
      'hours': '$h',
    });
  }
  if (h > 0) {
    return 'my_products_top_left_hm'.trParams({
      'hours': '$h',
      'mins': '$m',
    });
  }
  return 'my_products_top_left_m'.trParams({'mins': '$m'});
}

/// Egasi uchun mahsulot amallar sheet'i.
Future<OwnProductAction?> showOwnProductActionsSheet(
  BuildContext context, {
  required Product product,
}) {
  final c = context.appColors;
  final published = product.status == 'published';
  final isTop = product.isTop;
  final isQueued = product.isTopQueued;

  return showModalBottomSheet<OwnProductAction>(
    context: context,
    backgroundColor: c.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.dp)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.dp, 10.dp, 16.dp, 16.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(2.dp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.dp),
              Text(
                '${product.price} · ${product.views} · ${product.status}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isTop) ...[
                SizedBox(height: 8.dp),
                Text(
                  'my_products_top_countdown'.trParams({
                    'time': formatTopCountdown(product.topSecondsLeft),
                  }),
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (isQueued) ...[
                SizedBox(height: 8.dp),
                Text(
                  'my_products_top_queue_pos'.trParams({
                    'pos': '${product.topQueuePosition ?? '—'}',
                  }),
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              SizedBox(height: 12.dp),
              _tile(
                c,
                icon: Icons.edit_rounded,
                label: 'my_products_edit'.tr,
                onTap: () => Navigator.pop(ctx, OwnProductAction.edit),
              ),
              if (!isQueued)
                _tile(
                  c,
                  icon: Icons.vertical_align_top_rounded,
                  label: isTop
                      ? 'my_products_boost_extend'.tr
                      : 'my_products_boost_top'.tr,
                  subtitle: isTop
                      ? 'my_products_boost_extend_hint'.tr
                      : 'my_products_boost_price'.tr,
                  onTap: () => Navigator.pop(ctx, OwnProductAction.boostTop),
                ),
              if (isQueued)
                _tile(
                  c,
                  icon: Icons.hourglass_top_rounded,
                  label: 'my_products_top_queued'.tr,
                  subtitle: 'my_products_top_queue_pos'.trParams({
                    'pos': '${product.topQueuePosition ?? '—'}',
                  }),
                  onTap: () {},
                ),
              _tile(
                c,
                icon: published
                    ? Icons.visibility_off_outlined
                    : Icons.publish_rounded,
                label: published
                    ? 'my_products_unpublish'.tr
                    : 'my_products_publish'.tr,
                onTap: () => Navigator.pop(
                  ctx,
                  published
                      ? OwnProductAction.unpublish
                      : OwnProductAction.publish,
                ),
              ),
              _tile(
                c,
                icon: Icons.delete_outline_rounded,
                label: 'my_products_delete'.tr,
                danger: true,
                onTap: () => Navigator.pop(ctx, OwnProductAction.delete),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile(
  AppColors c, {
  required IconData icon,
  required String label,
  String? subtitle,
  required VoidCallback onTap,
  bool danger = false,
}) {
  final color = danger ? kListenRed : c.textPrimary;
  return ListTile(
    contentPadding: EdgeInsets.symmetric(horizontal: 4.dp),
    leading: Icon(icon, color: danger ? kListenRed : c.accent),
    title: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
    onTap: onTap,
  );
}
