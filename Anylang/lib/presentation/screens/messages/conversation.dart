import 'package:flutter/material.dart';
import '../../../data/core/mappers.dart';

/// Bitta suhbat (Xabarlar ro'yxati elementi) — direct yoki group.
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
  final bool isGroup;
  final bool pinned;
  final bool muted;
  final DateTime? lastMessageAt;
  final String? myRole;
  final bool isSuper;
  final String? inviteLink;
  final int? memberLimit;

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
    this.isGroup = false,
    this.pinned = false,
    this.muted = false,
    this.lastMessageAt,
    this.myRole,
    this.isSuper = false,
    this.inviteLink,
    this.memberLimit,
  });

  factory Conversation.fromApi(Map<String, dynamic> json) {
    final isGroup = json['type']?.toString() == 'group';
    final peer = Map<String, dynamic>.from(json['interlocutor'] as Map? ?? {});
    final peerId = (peer['id'] as num?)?.toInt() ?? 0;
    final groupTitle = (json['title'] as String?)?.trim();
    final name = isGroup
        ? (groupTitle?.isNotEmpty == true ? groupTitle! : 'Guruh')
        : (peer['full_name'] as String?)?.trim().isNotEmpty == true
            ? peer['full_name'] as String
            : 'User';
    final last = json['last_message'] as Map?;
    final lastText = last == null
        ? ''
        : (last['text'] as String?) ??
            (last['type'] == 'voice'
                ? 'Ovozli xabar'
                : (last['type']?.toString() ?? ''));
    final lastAt = json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'].toString())
        : null;
    final unread = (json['unread_count'] as num?)?.toInt() ?? 0;
    final idForGradient = isGroup
        ? ((json['id'] as num?)?.toInt() ?? 0)
        : peerId;
    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      peerId: peerId,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(idForGradient),
      initialColor: initialColorFor(idForGradient),
      name: name,
      lastMessage: lastText,
      time: formatChatTime(lastAt),
      online: !isGroup && peer['is_online'] == true,
      unread: unread,
      highlighted: unread > 0,
      avatarUrl: isGroup
          ? json['avatar_url'] as String?
          : peer['avatar_url'] as String?,
      isGroup: isGroup,
      pinned: json['pinned'] == true,
      muted: json['muted'] == true,
      lastMessageAt: lastAt,
      myRole: json['my_role']?.toString(),
      isSuper: json['is_super'] == true,
      inviteLink: json['invite_link']?.toString(),
      memberLimit: (json['member_limit'] as num?)?.toInt(),
    );
  }

  Conversation copyWith({
    String? lastMessage,
    String? time,
    bool? online,
    int? unread,
    bool? highlighted,
    bool? pinned,
    bool? muted,
  }) {
    return Conversation(
      id: id,
      peerId: peerId,
      initial: initial,
      avatarGradient: avatarGradient,
      initialColor: initialColor,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      online: online ?? this.online,
      unread: unread ?? this.unread,
      highlighted: highlighted ?? this.highlighted,
      avatarUrl: avatarUrl,
      isGroup: isGroup,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      lastMessageAt: lastMessageAt,
      myRole: myRole,
      isSuper: isSuper,
      inviteLink: inviteLink,
      memberLimit: memberLimit,
    );
  }
}
