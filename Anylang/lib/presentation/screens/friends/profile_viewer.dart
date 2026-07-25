import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';

/// «Kim sizni qidirdi» — profilingizni ko‘rgan foydalanuvchi.
class ProfileViewer {
  final int userId;
  final String name;
  final String? country;
  final String? businessRole;
  final String? avatarUrl;
  final bool isBusiness;
  final int viewCount;
  final DateTime? lastViewedAt;
  final String initial;
  final LinearGradient avatarGradient;

  const ProfileViewer({
    required this.userId,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    this.country,
    this.businessRole,
    this.avatarUrl,
    this.isBusiness = false,
    this.viewCount = 1,
    this.lastViewedAt,
  });

  factory ProfileViewer.fromApi(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    final safeName = (name == null || name.isEmpty) ? 'User' : name;
    final id = (json['user_id'] as num?)?.toInt() ?? 0;
    DateTime? last;
    final rawLast = json['last_viewed_at']?.toString();
    if (rawLast != null && rawLast.isNotEmpty) {
      last = DateTime.tryParse(rawLast)?.toLocal();
    }
    return ProfileViewer(
      userId: id,
      name: safeName,
      country: (json['country'] as String?)?.trim(),
      businessRole: (json['business_role'] as String?)?.trim(),
      avatarUrl: (json['avatar_url'] as String?)?.trim(),
      isBusiness: json['is_business'] == true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 1,
      lastViewedAt: last,
      initial: initialsOf(safeName),
      avatarGradient: avatarGradientFor(id),
    );
  }
}
