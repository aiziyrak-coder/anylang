import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';

class OwnListing {
  final int id;
  final LinearGradient tileGradient;
  final String name;
  final String price;
  final String? imageUrl;
  final String status;
  final bool isTop;
  final String? topRequestStatus;

  const OwnListing({
    required this.tileGradient,
    required this.name,
    required this.price,
    this.id = 0,
    this.imageUrl,
    this.status = 'published',
    this.isTop = false,
    this.topRequestStatus,
  });
}

String businessRoleLabel(String? apiRole) {
  final key = (apiRole ?? '').trim().toLowerCase();
  if (key.isEmpty) return '';
  return 'business_role_$key';
}

class ProfileAccount {
  final int id;
  final bool isBusiness;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool verified;
  final String flagAsset;
  /// ISO alpha-2 (API uchun).
  final String countryCode;
  /// Ko'rinadigan nom (Oʻzbekiston).
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
  /// API role code: manufacturer | distributor | retail | service
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
    required this.countryCode,
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

  String get roleLabel {
    final k = businessRoleLabel(role);
    return k.isEmpty ? '' : k;
  }

  factory ProfileAccount.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final personalName = (json['full_name'] as String?) ?? 'User';
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
    final company = (biz?['company_name'] as String?)?.trim();
    final displayName = isBusiness && company != null && company.isNotEmpty
        ? company
        : personalName;

    return ProfileAccount(
      id: id,
      isBusiness: isBusiness,
      name: displayName,
      initial: initialsOf(displayName),
      avatarGradient: avatarGradientFor(id),
      verified: json['verified_badge'] == true,
      flagAsset: flagAssetForCountry(countryCode),
      countryCode: countryCode.toUpperCase(),
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
      avatarUrl: (() {
        final top = (json['avatar_url'] as String?)?.trim();
        final logo = (biz == null ? null : biz['logo_url'] as String?)?.trim();
        if (isBusiness) {
          if (logo != null && logo.isNotEmpty) return logo;
          if (top != null && top.isNotEmpty) return top;
          return null;
        }
        return (top != null && top.isNotEmpty) ? top : null;
      })(),
      email: json['email'] as String?,
    );
  }

  ProfileAccount copyWith({
    List<OwnListing>? listings,
    int? listingsCount,
    String? avatarUrl,
    String? name,
    String? initial,
    String? email,
  }) {
    return ProfileAccount(
      id: id,
      isBusiness: isBusiness,
      name: name ?? this.name,
      initial: initial ?? this.initial,
      avatarGradient: avatarGradient,
      verified: verified,
      flagAsset: flagAsset,
      countryCode: countryCode,
      country: country,
      username: username,
      nativeLanguage: nativeLanguage,
      memberSince: memberSince,
      subscriptionPlan: subscriptionPlan,
      subscriptionPeriod: subscriptionPeriod,
      subscriptionLabel: subscriptionLabel,
      subscriptionExpiresAt: subscriptionExpiresAt,
      subscriptionActive: subscriptionActive,
      showPremiumBadge: showPremiumBadge,
      role: role,
      listingsCount: listingsCount ?? this.listingsCount,
      viewsCount: viewsCount,
      rating: rating,
      listings: listings ?? this.listings,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
    );
  }
}
