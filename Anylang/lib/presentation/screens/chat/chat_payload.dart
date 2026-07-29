import 'package:flutter/material.dart';

/// Chat ekraniga o'tishda beriladigan suhbatdosh / chat ma'lumoti.
class ChatPayload {
  final int chatId;
  final int peerId;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool online;
  final String? avatarUrl;
  final bool isGroup;
  final bool pinned;

  /// Guruhdagi rol (owner|admin|member).
  final String? myRole;
  final bool isSuper;
  final String? inviteLink;

  /// Marketplace soha guruhi (Textile Group va h.k.).
  final bool isMarketplace;
  final String? marketplaceSlug;
  final bool isSaved;

  const ChatPayload({
    required this.chatId,
    required this.peerId,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    this.online = false,
    this.avatarUrl,
    this.isGroup = false,
    this.pinned = false,
    this.myRole,
    this.isSuper = false,
    this.inviteLink,
    this.isMarketplace = false,
    this.marketplaceSlug,
    this.isSaved = false,
  });
}
