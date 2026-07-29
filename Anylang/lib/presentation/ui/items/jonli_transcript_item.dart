import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../utils/size_controller.dart';
import '../theme/colors.dart';
import '../transcript_shimmer.dart';
import '../../screens/jonli/jonli_transcript_entry.dart';

/// Jonli transkript: men — chap, suhbatdosh — o‘ng (chatdagi STT UX).
class JonliTranscriptItem extends StatelessWidget {
  final JonliTranscriptEntry entry;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  const JonliTranscriptItem({
    super.key,
    required this.entry,
    this.onRetry,
    this.onCopy,
  });

  String _hhmm(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isMe = entry.isMe;
    final speakerColor = isMe ? c.accent : kSpeakBlue;
    final timeLabel = _hhmm(entry.at);
    final speakerLabel =
        (isMe ? 'jonli_you' : 'jonli_interlocutor').tr;
    final bubbleBg = isMe
        ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.14)
        : c.surface.withValues(alpha: c.isDark ? 0.92 : 0.95);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: SizeController.screenWidth * 0.78),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.dp),
            topRight: Radius.circular(16.dp),
            bottomLeft: Radius.circular(isMe ? 16.dp : 4.dp),
            bottomRight: Radius.circular(isMe ? 4.dp : 16.dp),
          ),
          onLongPress: entry.pending
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onCopy?.call();
                },
          child: Ink(
            padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.dp),
                topRight: Radius.circular(16.dp),
                bottomLeft: Radius.circular(isMe ? 16.dp : 4.dp),
                bottomRight: Radius.circular(isMe ? 4.dp : 16.dp),
              ),
              border: Border.all(
                color: entry.pending
                    ? speakerColor.withValues(alpha: 0.45)
                    : entry.failed
                        ? c.danger.withValues(alpha: 0.45)
                        : c.surfaceBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8.dp,
                      height: 8.dp,
                      decoration: BoxDecoration(
                        color: speakerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    Text(
                      speakerLabel,
                      style: TextStyle(
                        color: speakerColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.fromCamera) ...[
                      SizedBox(width: 6.dp),
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 13.dp,
                        color: c.textFaint,
                      ),
                    ],
                    const Spacer(),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: c.textFaint,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.dp),
                if (entry.pending && entry.original.isEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          size: 16.dp, color: c.textFaint),
                      SizedBox(width: 6.dp),
                      Expanded(
                        child: Text(
                          'voice_transcribing'.tr,
                          style: TextStyle(
                            color: c.textFaint,
                            fontSize: 12.sp,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.dp),
                  TranscriptShimmer(
                      color: c.textFaint.withValues(alpha: 0.35)),
                ] else
                  Text(
                    entry.original.isEmpty ? '…' : entry.original,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                SizedBox(height: 8.dp),
                if (entry.pending && entry.translated.isEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 16.dp,
                        color: c.accent.withValues(alpha: 0.85),
                      ),
                      SizedBox(width: 6.dp),
                      Expanded(
                        child: Text(
                          'voice_transcribing'.tr,
                          style: TextStyle(
                            color: c.accent.withValues(alpha: 0.85),
                            fontSize: 12.sp,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.dp),
                  TranscriptShimmer(
                      color: c.accent.withValues(alpha: 0.35)),
                ] else if (entry.failed) ...[
                  Text(
                    'jonli_translate_failed'.tr,
                    style: TextStyle(
                      color: c.danger,
                      fontSize: 14.sp,
                    ),
                  ),
                  if (onRetry != null &&
                      (entry.audioPath ?? '').isNotEmpty) ...[
                    SizedBox(height: 10.dp),
                    Material(
                      color: c.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.dp),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.dp),
                        onTap: onRetry,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.dp,
                            vertical: 8.dp,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded,
                                  size: 16.dp, color: c.danger),
                              SizedBox(width: 6.dp),
                              Text(
                                'jonli_retry'.tr,
                                style: TextStyle(
                                  color: c.danger,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else
                  Text(
                    entry.translated.isEmpty ? '…' : entry.translated,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 15.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.dp),
      child: Align(
        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
        child: bubble,
      ),
    );
  }
}
