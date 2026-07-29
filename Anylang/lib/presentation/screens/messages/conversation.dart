import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  final DateTime? mutedUntil;
  final DateTime? lastMessageAt;
  final String? myRole;
  final bool isSuper;
  final String? inviteLink;
  final int? memberLimit;
  final bool isMarketplace;
  final String? marketplaceSlug;
  final bool isSaved;

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
    this.mutedUntil,
    this.lastMessageAt,
    this.myRole,
    this.isSuper = false,
    this.inviteLink,
    this.memberLimit,
    this.isMarketplace = false,
    this.marketplaceSlug,
    this.isSaved = false,
  });

  factory Conversation.fromApi(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final isGroup = type == 'group';
    final isSaved = type == 'saved' || json['is_saved'] == true;
    final peer = Map<String, dynamic>.from(json['interlocutor'] as Map? ?? {});
    final peerId = (peer['id'] as num?)?.toInt() ?? 0;
    final groupTitle = (json['title'] as String?)?.trim();
    final name = isSaved
        ? 'saved_messages_title'.tr
        : isGroup
            ? (groupTitle?.isNotEmpty == true ? groupTitle! : 'Guruh')
            : (peer['full_name'] as String?)?.trim().isNotEmpty == true
                ? peer['full_name'] as String
                : 'User';
    final last = json['last_message'] as Map?;
    final lastType = last?['type']?.toString();
    final lastText = last == null
        ? (isSaved ? 'saved_messages_hint'.tr : '')
        : (last['text'] as String?) ??
            (lastType == 'voice'
                ? 'chat_preview_voice'.tr
                : lastType == 'video'
                    ? ((last['meta'] is Map &&
                            (last['meta'] as Map)['is_round_note'] == true)
                        ? 'chat_preview_round_video'.tr
                        : 'chat_preview_video'.tr)
                    : lastType == 'image'
                        ? 'chat_preview_photo'.tr
                        : (lastType ?? ''));
    final lastAt = json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'].toString())
        : null;
    final unread = (json['unread_count'] as num?)?.toInt() ?? 0;
    final idForGradient = isGroup || isSaved
        ? ((json['id'] as num?)?.toInt() ?? 0)
        : peerId;
    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      peerId: peerId,
      initial: isSaved ? 'S' : initialsOf(name),
      avatarGradient: avatarGradientFor(idForGradient),
      initialColor: initialColorFor(idForGradient),
      name: name,
      lastMessage: lastText,
      time: formatChatTime(lastAt),
      online: !isGroup && !isSaved && peer['is_online'] == true,
      unread: unread,
      highlighted: unread > 0,
      avatarUrl: isGroup
          ? json['avatar_url'] as String?
          : (isSaved ? null : peer['avatar_url'] as String?),
      isGroup: isGroup,
      pinned: json['pinned'] == true || isSaved,
      muted: json['muted'] == true,
      mutedUntil: json['muted_until'] != null
          ? DateTime.tryParse(json['muted_until'].toString())
          : null,
      lastMessageAt: lastAt,
      myRole: json['my_role']?.toString(),
      isSuper: json['is_super'] == true,
      inviteLink: json['invite_link']?.toString(),
      memberLimit: (json['member_limit'] as num?)?.toInt(),
      isMarketplace: json['is_marketplace'] == true ||
          (json['marketplace_slug']?.toString().isNotEmpty == true),
      marketplaceSlug: json['marketplace_slug']?.toString(),
      isSaved: isSaved,
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
    DateTime? mutedUntil,
    bool clearMutedUntil = false,
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
      mutedUntil: clearMutedUntil ? null : (mutedUntil ?? this.mutedUntil),
      lastMessageAt: lastMessageAt,
      myRole: myRole,
      isSuper: isSuper,
      inviteLink: inviteLink,
      memberLimit: memberLimit,
      isMarketplace: isMarketplace,
      marketplaceSlug: marketplaceSlug,
      isSaved: isSaved,
    );
  }
}
