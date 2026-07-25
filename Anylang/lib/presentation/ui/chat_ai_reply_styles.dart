import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// AI javob uslublari (chat xabar ostida / sheet).
class AiReplyStyle {
  final String tone;
  final String emoji;
  final String labelKey;

  const AiReplyStyle({
    required this.tone,
    required this.emoji,
    required this.labelKey,
  });
}

const kAiReplyStyles = <AiReplyStyle>[
  AiReplyStyle(
    tone: 'professional',
    emoji: '👍',
    labelKey: 'ai_reply_professional',
  ),
  AiReplyStyle(
    tone: 'friendly',
    emoji: '😊',
    labelKey: 'ai_reply_friendly',
  ),
  AiReplyStyle(
    tone: 'sales',
    emoji: '💼',
    labelKey: 'ai_reply_sales',
  ),
  AiReplyStyle(
    tone: 'negotiation',
    emoji: '🤝',
    labelKey: 'ai_reply_negotiation',
  ),
];

class ChatAiReplyStyles extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final bool loading;
  final String? activeTone;

  const ChatAiReplyStyles({
    super.key,
    required this.onSelect,
    this.loading = false,
    this.activeTone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Wrap(
      spacing: 6.dp,
      runSpacing: 6.dp,
      children: [
        for (final s in kAiReplyStyles)
          _StyleChip(
            emoji: s.emoji,
            label: s.labelKey.tr,
            loading: loading && activeTone == s.tone,
            enabled: !loading,
            colors: c,
            onTap: () => onSelect(s.tone),
          ),
      ],
    );
  }
}

class _StyleChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool loading;
  final bool enabled;
  final AppColors colors;
  final VoidCallback onTap;

  const _StyleChip({
    required this.emoji,
    required this.label,
    required this.loading,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final radius = BorderRadius.circular(16.dp);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 7.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: c.outline.withValues(alpha: 0.55),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 12.dp,
                  height: 12.dp,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: c.accent,
                  ),
                )
              else
                Text(emoji, style: TextStyle(fontSize: 13.sp)),
              SizedBox(width: 5.dp),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? c.textPrimary : c.textFaint,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
