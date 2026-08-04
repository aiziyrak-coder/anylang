import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../screens/friends/friend.dart';
import '../screens/friends/profile_viewer.dart';

/// Profil statistikasi sheetlari uchun umumiy odam elementi.
class ProfilePeopleItem {
  final int userId;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final String subtitle;
  final bool isBusiness;
  final String? country;
  final String? businessRole;

  const ProfilePeopleItem({
    required this.userId,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.subtitle,
    this.avatarUrl,
    this.isBusiness = false,
    this.country,
    this.businessRole,
  });

  factory ProfilePeopleItem.fromViewer(ProfileViewer v) {
    final subtitle = v.viewCount > 1
        ? 'profile_stat_views_count'.trParams({'n': '${v.viewCount}'})
        : 'profile_viewers_saw'.tr;
    return ProfilePeopleItem(
      userId: v.userId,
      name: v.name,
      initial: v.initial,
      avatarGradient: v.avatarGradient,
      avatarUrl: v.avatarUrl,
      subtitle: subtitle,
      isBusiness: v.isBusiness,
      country: v.country,
      businessRole: v.businessRole,
    );
  }

  factory ProfilePeopleItem.fromFriend(Friend f) {
    final role = (f.businessRole ?? '').trim();
    final country = (f.country ?? '').trim().toUpperCase();
    final parts = <String>[
      if (role.isNotEmpty) role,
      if (country.length == 2) country,
    ];
    return ProfilePeopleItem(
      userId: f.id,
      name: f.name,
      initial: f.initial,
      avatarGradient: f.avatarGradient,
      avatarUrl: f.avatarUrl,
      subtitle: parts.isEmpty ? (f.online ? 'friends_online'.tr : '') : parts.join(' · '),
      isBusiness: f.isBusiness,
      country: f.country,
      businessRole: f.businessRole,
    );
  }

  factory ProfilePeopleItem.fromLiker(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    final safeName = (name == null || name.isEmpty) ? 'User' : name;
    final id = (json['user_id'] as num?)?.toInt() ?? 0;
    final product = (json['product_title'] as String?)?.trim() ?? '';
    return ProfilePeopleItem(
      userId: id,
      name: safeName,
      initial: initialsOf(safeName),
      avatarGradient: avatarGradientFor(id),
      avatarUrl: (json['avatar_url'] as String?)?.trim(),
      subtitle: product.isEmpty
          ? 'profile_stat_liked_product'.tr
          : 'profile_stat_liked_named'.trParams({'title': product}),
      isBusiness: json['is_business'] == true,
      country: (json['country'] as String?)?.trim(),
      businessRole: (json['business_role'] as String?)?.trim(),
    );
  }
}
