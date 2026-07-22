import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';
import '../../ui/theme/gradients.dart';

class OwnListing {
  final int id;
  final LinearGradient tileGradient;
  final String name;
  final String price;

  const OwnListing({
    required this.tileGradient,
    required this.name,
    required this.price,
    this.id = 0,
  });
}

class ProfileAccount {
  final int id;
  final bool isBusiness;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool verified;
  final String flagAsset;
  final String country;
  final String? username;
  final String? nativeLanguage;
  final String? memberSince;
  final String? subscriptionPlan;
  final String? subscriptionPeriod;
  final DateTime? subscriptionExpiresAt;
  final String? role;
  final int? listingsCount;
  final String? viewsCount;
  final double? rating;
  final List<OwnListing> listings;
  final String? avatarUrl;
  final String? email;

  const ProfileAccount({
    required this.isBusiness,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.flagAsset,
    required this.country,
    this.id = 0,
    this.verified = false,
    this.username,
    this.nativeLanguage,
    this.memberSince,
    this.subscriptionPlan,
    this.subscriptionPeriod,
    this.subscriptionExpiresAt,
    this.role,
    this.listingsCount,
    this.viewsCount,
    this.rating,
    this.listings = const [],
    this.avatarUrl,
    this.email,
  });

  factory ProfileAccount.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final name = (json['full_name'] as String?) ?? 'User';
    final number = json['number']?.toString() ?? '';
    final isBusiness = json['is_business'] == true;
    final biz = json['business'] as Map?;
    final sub = json['subscription'] as Map?;
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final expires = DateTime.tryParse(sub?['expires_at']?.toString() ?? '');
    final plan = sub?['plan']?.toString();
    final countryCode = (json['country'] as String?) ?? '';
    return ProfileAccount(
      id: id,
      isBusiness: isBusiness,
      name: isBusiness
          ? ((biz?['company_name'] as String?)?.isNotEmpty == true
              ? biz!['company_name'] as String
              : name)
          : name,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      verified: json['verified_badge'] == true,
      flagAsset: countryCode.toUpperCase() == 'TR'
          ? 'assets/images/flag_tr.png'
          : 'assets/images/flag_uz.png',
      country: countryCode.isEmpty ? '—' : countryCode,
      username: number.isEmpty ? null : formatNumber(number),
      nativeLanguage: json['native_language'] as String?,
      memberSince: created == null ? null : '${created.month}.${created.year}',
      subscriptionPlan: plan,
      subscriptionPeriod: sub?['billing_cycle']?.toString(),
      subscriptionExpiresAt: expires,
      role: biz?['business_role']?.toString(),
      listingsCount: (biz?['stats'] is Map)
          ? ((biz!['stats'] as Map)['listings_count'] as num?)?.toInt()
          : null,
      viewsCount: (biz?['stats'] is Map)
          ? formatViews(((biz!['stats'] as Map)['total_views'] as num?)?.toInt() ?? 0)
          : null,
      rating: (biz?['stats'] is Map)
          ? ((biz!['stats'] as Map)['rating'] as num?)?.toDouble()
          : null,
      avatarUrl: isBusiness
          ? (biz == null ? null : biz['logo_url'] as String?)
          : json['avatar_url'] as String?,
      email: json['email'] as String?,
    );
  }
}
