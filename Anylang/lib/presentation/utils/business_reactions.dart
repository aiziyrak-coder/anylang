import 'package:get/get.dart';

/// Biznes chat reaksiyalari (👍 o‘rniga deal statuslari).
class BusinessReaction {
  final String emoji;
  final String labelKey;

  const BusinessReaction({required this.emoji, required this.labelKey});

  String get label => labelKey.tr;

  String get chipText => '$emoji $label';
}

const kBusinessReactions = <BusinessReaction>[
  BusinessReaction(emoji: '✔', labelKey: 'biz_react_confirmed'),
  BusinessReaction(emoji: '📦', labelKey: 'biz_react_ready'),
  BusinessReaction(emoji: '🚢', labelKey: 'biz_react_shipping'),
  BusinessReaction(emoji: '💵', labelKey: 'biz_react_paid'),
  BusinessReaction(emoji: '🛃', labelKey: 'biz_react_customs'),
];

/// Eski oddiy emoji — hali ham qabul qilinadi / ko‘rsatiladi.
const kClassicReactions = <String>[
  '👍',
  '❤️',
  '😂',
  '🔥',
  '😢',
  '🎉',
  '🙏',
  '👏',
  '🤝',
  '💯',
];

BusinessReaction? businessReactionFor(String? emoji) {
  if (emoji == null || emoji.isEmpty) return null;
  for (final r in kBusinessReactions) {
    if (r.emoji == emoji) return r;
  }
  return null;
}

String reactionDisplayText(String emoji, {Object? count}) {
  final biz = businessReactionFor(emoji);
  final label = biz?.label;
  final n = count;
  final countStr = (n == null || n.toString().isEmpty || n.toString() == '1')
      ? ''
      : ' ${n.toString()}';
  if (label != null) return '$emoji $label$countStr'.trim();
  return '$emoji$countStr'.trim();
}
