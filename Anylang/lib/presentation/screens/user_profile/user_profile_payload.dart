import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';

class UserProfilePayload {
  final int id;
  final bool business;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool verified;
  final String flagAsset;
  final String country;
  final String role;
  final String phone;
  final String? experience;
  final String? website;
  final int? completeness;
  final List<String> certificates;
  final int listings;
  final String? avatarUrl;

  const UserProfilePayload({
    required this.business,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.flagAsset,
    required this.country,
    required this.role,
    required this.phone,
    this.id = 0,
    this.verified = false,
    this.experience,
    this.website,
    this.completeness,
    this.certificates = const [],
    this.listings = 0,
    this.avatarUrl,
  });

  factory UserProfilePayload.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final isBusiness = json['is_business'] == true;
    final name = (json['name'] as String?) ??
        (json['full_name'] as String?) ??
        'User';
    final country = (json['country'] as String?) ?? '';
    final biz = json['business'] as Map?;
    final number = json['number']?.toString() ?? '';
    final avatar = isBusiness
        ? (biz?['logo_url'] as String?)
        : (json['avatar_url'] as String?);
    return UserProfilePayload(
      id: id,
      business: isBusiness,
      name: name,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      country: formatCountryName(country),
      role: (json['subtitle_role'] as String?) ?? '',
      phone: number.isEmpty ? '' : formatNumber(number),
      experience: biz?['founded_year'] != null
          ? '${biz!['founded_year']} yildan'
          : null,
      website: biz?['website'] as String?,
      completeness: (biz?['completeness'] as num?)?.toInt(),
      certificates: (biz?['certificates'] is List)
          ? (biz!['certificates'] as List).map((e) => e.toString()).toList()
          : const [],
      listings: (biz?['stats'] is Map)
          ? ((biz!['stats'] as Map)['listings_count'] as num?)?.toInt() ?? 0
          : 0,
      flagAsset: flagAssetForCountry(country),
      verified: json['verified_badge'] == true,
      avatarUrl: avatar,
    );
  }
}
