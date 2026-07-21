import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';

/// Chat (suhbat) ekraniga o'tishda beriladigan suhbatdosh ma'lumoti.
/// `messages` ro'yxatiga to'g'ridan-to'g'ri bog'liq emas — ekran mock
/// xabarlarni o'zi yuklaydi (keyinchalik backend bilan almashtiriladi).
class ChatPayload {
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool online;

  const ChatPayload({
    required this.name,
    required this.initial,
    required this.avatarGradient,
    this.online = false,
  });
}

/// Namuna suhbatdosh (dizayndagi Anna Müller holati).
const ChatPayload kAnnaChat = ChatPayload(
  name: 'Anna Müller',
  initial: 'A',
  avatarGradient: avatarTealGradient,
  online: true,
);
