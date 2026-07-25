import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/chat/chat_message.dart';
import '../utils/size_controller.dart';
import '../utils/smart_pin.dart';
import 'theme/colors.dart';

/// Chat yuqorisidagi Smart Pin paneli — Contract / Product / Address / Invoice.
class ChatSmartPinsBar extends StatelessWidget {
  final List<ChatMessage> pins;
  final ValueChanged<String> onTapPin;
  final VoidCallback? onOpenAll;

  const ChatSmartPinsBar({
    super.key,
    required this.pins,
    required this.onTapPin,
    this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.shrink();
    final c = context.appColors;

    // Har turdan eng yangisini (ro‘yxat oxiri yangiroq deb) ustun ko‘rsatamiz.
    final byKind = <SmartPinKind, ChatMessage>{};
    for (final p in pins) {
      final kind = classifySmartPin(p).kind;
      byKind[kind] = p; // oxirgisi g‘olib
    }
    // Ko‘rinish tartibi: contract → product → address → invoice → other
    const order = [
      SmartPinKind.contract,
      SmartPinKind.product,
      SmartPinKind.address,
      SmartPinKind.invoice,
      SmartPinKind.other,
    ];
    final ordered = <ChatMessage>[
      for (final k in order)
        if (byKind.containsKey(k)) byKind[k]!,
    ];
    // Agar bir xil turdan bir nechta bo‘lsa — “+N”
    final extra = pins.length - ordered.length;

    return Material(
      color: c.surface.withValues(alpha: 0.94),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.surfaceBorder, width: 0.7),
          ),
        ),
        padding: EdgeInsets.fromLTRB(10.dp, 8.dp, 10.dp, 8.dp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 14.dp, color: c.accentText),
                SizedBox(width: 6.dp),
                Text(
                  'smart_pin_bar_title'.tr,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (pins.length > 1)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpenAll,
                      borderRadius: BorderRadius.circular(8.dp),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.dp,
                          vertical: 2.dp,
                        ),
                        child: Text(
                          'smart_pin_all'.trParams({'n': '${pins.length}'}),
                          style: TextStyle(
                            color: c.accentText,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.dp),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (i > 0) SizedBox(width: 8.dp),
                    _SmartPinChip(
                      message: ordered[i],
                      onTap: () => onTapPin(ordered[i].id),
                    ),
                  ],
                  if (extra > 0) ...[
                    SizedBox(width: 8.dp),
                    _MoreChip(count: extra, onTap: onOpenAll),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartPinChip extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onTap;

  const _SmartPinChip({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final info = classifySmartPin(message);
    final preview = smartPinPreview(message);
    final radius = BorderRadius.circular(14.dp);
    return Material(
      color: c.accentSoft,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(maxWidth: 210.dp),
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.emoji, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 6.dp),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _MoreChip({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(14.dp);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 14.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.outline.withValues(alpha: 0.55)),
          ),
          child: Text(
            '+$count',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
