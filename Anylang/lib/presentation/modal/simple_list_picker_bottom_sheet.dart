import 'package:flutter/material.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Umumiy bitta ustunli ro'yxatdan tanlash — pastdan chiqadigan sheet.
/// Tanlangan nomni qaytaradi (Rol, Valyuta, Kategoriya kabi oddiy ro'yxatlar
/// uchun). Davlat tanlash uchun `modal/country_picker_bottom_sheet.dart`.
Future<String?> showSimpleListPickerBottomSheet(
  BuildContext context, {
  required String title,
  required List<String> items,
  String? selected,
}) {
  final c = context.appColors;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
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
            SizedBox(height: 16.dp),
            Text(
              title,
              style: TextStyle(color: c.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.dp),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final name in items)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, name),
                          borderRadius: BorderRadius.circular(12.dp),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 8.dp),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: name == selected ? c.accent : c.textPrimary,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (name == selected)
                                  Icon(Icons.check_rounded, color: c.accent, size: 20.dp),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
