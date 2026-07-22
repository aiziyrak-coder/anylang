import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';

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
  final String? subscriptionLabel;
  final DateTime? subscriptionExpiresAt;
  final bool subscriptionActive;
  final bool showPremiumBadge;
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
    this.subscriptionLabel,
    this.subscriptionExpiresAt,
    this.subscriptionActive = false,
    this.showPremiumBadge = false,
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
    final started = DateTime.tryParse(sub?['started_at']?.toString() ?? '');
    final expires = DateTime.tryParse(sub?['expires_at']?.toString() ?? '');
    final plan = sub?['plan']?.toString();
    final billing = sub?['billing_cycle']?.toString();
    final isActive = sub?['is_active'] == true;
    final countryCode = (json['country'] as String?) ?? '';
    final planKey = plan?.toLowerCase();
    final showPremium = !isBusiness && isActive && planKey == 'premium';

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
      flagAsset: flagAssetForCountry(countryCode),
      country: formatCountryName(countryCode),
      username: number.isEmpty ? null : formatNumber(number),
      nativeLanguage: formatLanguageName(json['native_language'] as String?),
      memberSince: formatMonthYear(created),
      subscriptionPlan: formatSubscriptionPlan(plan),
      subscriptionPeriod: formatSubscriptionPeriod(
        billingCycle: billing,
        startedAt: started,
        expiresAt: expires,
      ),
      subscriptionLabel: formatSubscriptionLabel(
        plan: plan,
        billingCycle: billing,
        startedAt: started,
        expiresAt: expires,
      ),
      subscriptionExpiresAt: expires,
      subscriptionActive: isActive,
      showPremiumBadge: showPremium,
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
