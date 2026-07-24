import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';

/// Kiruvchi do'stlik so'rovi (`GET /friends/requests?type=incoming`).
class FriendRequest {
  final int requestId;
  final int userId;
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final String name;
  final String subtitle;
  final bool online;

  const FriendRequest({
    required this.requestId,
    required this.userId,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.online = false,
  });

  factory FriendRequest.fromApi(Map<String, dynamic> json) {
    final requestId = (json['id'] as num?)?.toInt() ?? 0;
    final user = Map<String, dynamic>.from(json['user'] as Map? ?? const {});
    final id = (user['id'] as num?)?.toInt() ?? 0;
    final name = (user['full_name'] as String?) ?? 'User';
    final number = user['number']?.toString() ?? '';
    final country = user['country']?.toString() ?? '';
    return FriendRequest(
      requestId: requestId,
      userId: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      avatarUrl: user['avatar_url'] as String?,
      name: name,
      subtitle: number.isEmpty
          ? (country.isEmpty ? '' : country)
          : [
              formatNumber(number),
              if (country.isNotEmpty) country,
            ].join(' · '),
      online: user['is_online'] == true,
    );
  }
}
