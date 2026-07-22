import 'package:flutter/material.dart';
import '../../../data/core/mappers.dart';

/// Bitta suhbat (Xabarlar ro'yxati elementi).
class Conversation {
  final int id;
  final int peerId;
  final String initial;
  final LinearGradient avatarGradient;
  final Color initialColor;
  final String name;
  final String lastMessage;
  final String time;
  final bool online;
  final int unread;
  final bool highlighted;
  final String? avatarUrl;

  const Conversation({
    required this.id,
    required this.peerId,
    required this.initial,
    required this.avatarGradient,
    required this.initialColor,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.online = false,
    this.unread = 0,
    this.highlighted = false,
    this.avatarUrl,
  });

  factory Conversation.fromApi(Map<String, dynamic> json) {
    final peer = Map<String, dynamic>.from(json['interlocutor'] as Map? ?? {});
    final peerId = (peer['id'] as num?)?.toInt() ?? 0;
    final name = (peer['full_name'] as String?)?.trim().isNotEmpty == true
        ? peer['full_name'] as String
        : 'User';
    final last = json['last_message'] as Map?;
    final lastText = last == null
        ? ''
        : (last['text'] as String?) ??
            (last['type'] == 'voice' ? 'Ovozli xabar' : (last['type']?.toString() ?? ''));
    final lastAt = json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'].toString())
        : null;
    final unread = (json['unread_count'] as num?)?.toInt() ?? 0;
    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      peerId: peerId,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(peerId),
      initialColor: initialColorFor(peerId),
      name: name,
      lastMessage: lastText,
      time: formatChatTime(lastAt),
      online: peer['is_online'] == true,
      unread: unread,
      highlighted: unread > 0,
      avatarUrl: peer['avatar_url'] as String?,
    );
  }
}
