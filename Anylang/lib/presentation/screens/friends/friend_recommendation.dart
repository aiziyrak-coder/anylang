import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../ui/ai_matching.dart';

/// AI soha bo‘yicha tavsiya qilingan kompaniya (Business Match).
class FriendRecommendation {
  final int userId;
  final String name;
  final String? country;
  final String? businessRole;
  final String? logoUrl;
  final String reason;
  final String headline;
  final int matchPercent;
  final bool verified;
  final String initial;
  final LinearGradient avatarGradient;

  const FriendRecommendation({
    required this.userId,
    required this.name,
    required this.reason,
    required this.initial,
    required this.avatarGradient,
    this.country,
    this.businessRole,
    this.logoUrl,
    this.headline = '',
    this.matchPercent = 0,
    this.verified = false,
  });

  factory FriendRecommendation.fromApi(Map<String, dynamic> json) {
    final name = (json['company_name'] as String?)?.trim();
    final safeName =
        (name == null || name.isEmpty) ? 'trade_ai_guest'.tr : name;
    final id = (json['user_id'] as num?)?.toInt() ?? 0;
    return FriendRecommendation(
      userId: id,
      name: safeName,
      country: (json['country'] as String?)?.trim(),
      businessRole: (json['business_role'] as String?)?.trim(),
      logoUrl: (json['logo_url'] as String?)?.trim(),
      reason: (json['reason'] as String?)?.trim() ?? '',
      headline: (json['headline'] as String?)?.trim() ?? '',
      matchPercent: (json['match_percent'] as num?)?.toInt() ?? 0,
      verified: json['verified'] == true,
      initial: initialsOf(safeName),
      avatarGradient: avatarGradientFor(id),
    );
  }

  factory FriendRecommendation.fromCompany(
    AiMatchCompany company, {
    required String reason,
    int matchPercent = 0,
    String headline = '',
  }) {
    final name =
        company.name.trim().isEmpty ? 'trade_ai_guest'.tr : company.name.trim();
    return FriendRecommendation(
      userId: company.id,
      name: name,
      country: company.country,
      businessRole: company.businessRole,
      logoUrl: company.logoUrl,
      reason: reason,
      headline: headline,
      matchPercent: matchPercent,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(company.id),
    );
  }

  /// Kartadagi asosiy sarlavha (masalan «Furniture Importer»).
  String get displayHeadline {
    final h = headline.trim();
    if (h.isNotEmpty) return h;
    final role = (businessRole ?? '').trim();
    if (role.isNotEmpty) return role;
    return name;
  }

  String get subtitle {
    final bits = <String>[
      if ((businessRole ?? '').trim().isNotEmpty) businessRole!.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim().toUpperCase(),
    ];
    return bits.join(' · ');
  }
}
