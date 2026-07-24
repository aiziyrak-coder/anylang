import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Telegram uslubidagi pastki tasdiqlash oynasi.
class TelegramSheetAction {
  final String id;
  final String label;
  final bool danger;
  final bool primary;

  const TelegramSheetAction({
    required this.id,
    required this.label,
    this.danger = false,
    this.primary = false,
  });
}

Future<String?> showTelegramActionSheet(
  BuildContext context, {
  required String title,
  String? body,
  required List<TelegramSheetAction> actions,
  String? cancelLabel,
}) {
  final cancel = cancelLabel ?? 'common_cancel'.tr;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.appColors;
      final sheetBg = c.isDark ? const Color(0xFF152A42) : Colors.white;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 12.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: BorderRadius.circular(16.dp),
                  border: Border.all(color: c.outline.withValues(alpha: 0.35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.dp, 18.dp, 20.dp, 8.dp),
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (body != null && body.trim().isNotEmpty) ...[
                            SizedBox(height: 8.dp),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13.sp,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.outline.withValues(alpha: 0.45)),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: c.outline.withValues(alpha: 0.35),
                        ),
                      _ActionTile(
                        label: actions[i].label,
                        danger: actions[i].danger,
                        primary: actions[i].primary,
                        onTap: () => Navigator.pop(ctx, actions[i].id),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 8.dp),
              Material(
                color: sheetBg,
                borderRadius: BorderRadius.circular(16.dp),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(16.dp),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 15.dp),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.dp),
                      border: Border.all(
                        color: c.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      cancel,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _ActionTile extends StatelessWidget {
  final String label;
  final bool danger;
  final bool primary;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.danger,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = danger
        ? kListenRed
        : (primary ? c.accentText : c.textPrimary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
