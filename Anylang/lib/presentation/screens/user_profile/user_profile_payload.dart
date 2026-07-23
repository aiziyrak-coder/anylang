import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  final List<String> factoryImageUrls;
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
    this.factoryImageUrls = const [],
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
    final roleRaw = ((json['subtitle_role'] as String?) ??
            (biz?['business_role'] as String?) ??
            '')
        .trim();
    String roleKey = '';
    if (roleRaw.isNotEmpty) {
      final lower = roleRaw.toLowerCase();
      if ({'manufacturer', 'distributor', 'retail', 'service'}.contains(lower)) {
        roleKey = 'business_role_$lower';
      } else {
        roleKey = roleRaw;
      }
    }
    final factoryUrls = <String>[];
    final factoryRaw = biz?['factory_images'];
    if (factoryRaw is List) {
      for (final e in factoryRaw) {
        if (e is Map) {
          final url = e['url']?.toString();
          if (url != null && url.isNotEmpty) factoryUrls.add(url);
        } else if (e is String && e.isNotEmpty) {
          factoryUrls.add(e);
        }
      }
    }
    final year = biz?['founded_year'];
    return UserProfilePayload(
      id: id,
      business: isBusiness,
      name: name,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      country: formatCountryName(country),
      role: roleKey,
      phone: number.isEmpty ? '' : formatNumber(number),
      experience: year != null
          ? 'profile_founded_year'.trParams({'year': '$year'})
          : null,
      website: biz?['website'] as String?,
      completeness: (biz?['completeness'] as num?)?.toInt(),
      certificates: (biz?['certificates'] is List)
          ? (biz!['certificates'] as List).map((e) => e.toString()).toList()
          : const [],
      factoryImageUrls: factoryUrls,
      listings: (biz?['stats'] is Map)
          ? ((biz!['stats'] as Map)['listings_count'] as num?)?.toInt() ?? 0
          : 0,
      flagAsset: flagAssetForCountry(country),
      verified: json['verified_badge'] == true,
      avatarUrl: avatar,
    );
  }
}
