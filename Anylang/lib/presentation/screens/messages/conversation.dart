import 'package:flutter/material.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';

/// Bitta suhbat (Xabarlar ro'yxati elementi). Hozircha mock — keyinchalik
/// backenddan keladi.
class Conversation {
  final String initial;
  final LinearGradient avatarGradient;
  final Color initialColor;
  final String name;
  final String lastMessage;
  final String time;
  final bool online;
  final int unread;
  final bool highlighted;

  const Conversation({
    required this.initial,
    required this.avatarGradient,
    required this.initialColor,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.online = false,
    this.unread = 0,
    this.highlighted = false,
  });
}

/// Namuna suhbatlar (dizayndagi holat). Keyinchalik so'rov bilan almashtiriladi.
const List<Conversation> kMockConversations = [
  Conversation(
    initial: 'A',
    avatarGradient: avatarTealGradient,
    initialColor: kLime,
    name: 'Anna Müller',
    lastMessage: 'Rahmat! Ertaga uchrashamizmi?',
    time: '14:32',
    online: true,
    unread: 2,
    highlighted: true,
  ),
  Conversation(
    initial: 'R',
    avatarGradient: avatarOliveGradient,
    initialColor: kAvatarFg,
    name: 'Ricardo Sánchez',
    lastMessage: 'Ovozli xabar · 0:12',
    time: '12:05',
  ),
  Conversation(
    initial: 'Y',
    avatarGradient: avatarMaroonGradient,
    initialColor: kAvatarFg,
    name: 'Yuki Tanaka',
    lastMessage: 'ありがとう → tarjima qilindi',
    time: 'Kecha',
    online: true,
  ),
  Conversation(
    initial: 'M',
    avatarGradient: avatarGreenGradient,
    initialColor: kAvatarFg,
    name: 'Marco Rossi',
    lastMessage: 'Ciao! Come stai?',
    time: 'Yak',
  ),
  Conversation(
    initial: 'S',
    avatarGradient: avatarSlateGradient,
    initialColor: kAvatarFg,
    name: 'Sophie Laurent',
    lastMessage: 'Merci beaucoup pour votre aide',
    time: 'Sha',
  ),
];
