import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/chat/chat_message.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';
import '../utils/smart_pin.dart';

/// Barcha pinlangan xabarlar — Smart Pin ro‘yxati.
Future<String?> showSmartPinsBottomSheet(
  BuildContext context, {
  required List<ChatMessage> pins,
}) {
  final c = context.appColors;
  // Yangisi yuqorida
  final items = pins.reversed.toList();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(12.dp, 12.dp, 12.dp, 20.dp),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.dp,
                  height: 5.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(5.dp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.dp),
                child: Text(
                  'smart_pin_all_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 8.dp),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4.dp),
                  itemBuilder: (_, i) {
                    final msg = items[i];
                    final info = classifySmartPin(msg);
                    final preview = smartPinPreview(msg);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, msg.id),
                        borderRadius: BorderRadius.circular(14.dp),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.dp,
                            vertical: 12.dp,
                          ),
                          child: Row(
                            children: [
                              Text(info.emoji, style: TextStyle(fontSize: 20.sp)),
                              SizedBox(width: 12.dp),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      info.label,
                                      style: TextStyle(
                                        color: c.accentText,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2.dp),
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: c.textFaint,
                                size: 22.dp,
                              ),
                            ],
                          ),
                        ),
                      ),
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
