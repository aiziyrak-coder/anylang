import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../ui/trust_score.dart';
import '../../ui/factory_verification.dart';
import '../../ui/scam_risk.dart';

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
  final String? description;
  final String? seoText;
  final List<String> keywords;
  final Map<String, String> descriptionI18n;
  final int? completeness;
  final List<String> certificates;
  final List<String> factoryImageUrls;
  final String? moq;
  final String? productionCapacity;
  final String? leadTime;
  final List<String> incoterms;
  final List<String> paymentMethods;
  final int listings;
  final String? avatarUrl;
  /// Agar chatdan ochilgan bo'lsa — "Xabar yozish" yangi ChatScreen ochmasdan orqaga qaytadi.
  final int? existingChatId;
  /// none | pending | accepted
  final String friendshipStatus;
  final int? friendshipRequestId;
  final bool isRequestIncoming;
  final TrustScore? trustScore;
  final FactoryVerification factoryVerification;
  final ScamRisk? scamRisk;
  final int networkingConnections;
  final int networkingCountries;
  final int? networkingTrust;
  /// true: ekran ochiladi, to‘liq profil API dan kelguncha shimmer.
  final bool loadFull;

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
    this.description,
    this.seoText,
    this.keywords = const [],
    this.descriptionI18n = const {},
    this.completeness,
    this.certificates = const [],
    this.factoryImageUrls = const [],
    this.moq,
    this.productionCapacity,
    this.leadTime,
    this.incoterms = const [],
    this.paymentMethods = const [],
    this.listings = 0,
    this.avatarUrl,
    this.existingChatId,
    this.friendshipStatus = 'none',
    this.friendshipRequestId,
    this.isRequestIncoming = false,
    this.trustScore,
    this.factoryVerification = const FactoryVerification(),
    this.scamRisk,
    this.networkingConnections = 0,
    this.networkingCountries = 0,
    this.networkingTrust,
    this.loadFull = false,
  });

  /// Chat / ro‘yxatdan tez ochish — to‘liq ma’lumot keyin yuklanadi.
  factory UserProfilePayload.preview({
    required int id,
    required String name,
    String? initial,
    LinearGradient? avatarGradient,
    String? avatarUrl,
    int? existingChatId,
  }) {
    final trimmed = name.trim().isEmpty ? 'User' : name.trim();
    return UserProfilePayload(
      id: id,
      business: false,
      name: trimmed,
      initial: initial ?? initialsOf(trimmed),
      avatarGradient: avatarGradient ?? avatarGradientFor(id),
      flagAsset: '',
      country: '',
      role: '',
      phone: '',
      avatarUrl: avatarUrl,
      existingChatId: existingChatId,
      loadFull: true,
    );
  }

  factory UserProfilePayload.fromApi(
    Map<String, dynamic> json, {
    int? existingChatId,
  }) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final isBusiness = json['is_business'] == true;
    final name = (json['name'] as String?) ??
        (json['full_name'] as String?) ??
        'User';
    final country = (json['country'] as String?) ?? '';
    final biz = json['business'] as Map?;
    final number = json['number']?.toString() ?? '';
    final avatar = (json['avatar_url'] as String?)?.trim().isNotEmpty == true
        ? json['avatar_url'] as String?
        : (biz?['logo_url'] as String?);
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
      description: (biz?['description'] as String?)?.trim(),
      seoText: (biz?['seo_text'] as String?)?.trim(),
      keywords: (biz?['keywords'] is List)
          ? (biz!['keywords'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : const [],
      descriptionI18n: () {
        final raw = biz?['description_i18n'];
        if (raw is! Map) return const <String, String>{};
        final out = <String, String>{};
        raw.forEach((k, v) {
          final code = k.toString();
          final text = (v?.toString() ?? '').trim();
          if (code.isNotEmpty && text.isNotEmpty) out[code] = text;
        });
        return out;
      }(),
      completeness: (biz?['completeness'] as num?)?.toInt(),
      certificates: (biz?['certificates'] is List)
          ? (biz!['certificates'] as List).map((e) => e.toString()).toList()
          : const [],
      factoryImageUrls: factoryUrls,
      moq: (biz?['moq'] as String?)?.trim(),
      productionCapacity: (biz?['production_capacity'] as String?)?.trim(),
      leadTime: (biz?['lead_time'] as String?)?.trim(),
      incoterms: (biz?['incoterms'] is List)
          ? (biz!['incoterms'] as List).map((e) => e.toString()).toList()
          : const [],
      paymentMethods: (biz?['payment_methods'] is List)
          ? (biz!['payment_methods'] as List).map((e) => e.toString()).toList()
          : const [],
      listings: (biz?['stats'] is Map)
          ? ((biz!['stats'] as Map)['listings_count'] as num?)?.toInt() ?? 0
          : 0,
      flagAsset: flagAssetForCountry(country),
      verified: json['verified_badge'] == true,
      avatarUrl: avatar,
      existingChatId: existingChatId,
      friendshipStatus: (json['friendship_status'] as String?) ?? 'none',
      friendshipRequestId: (json['friendship_request_id'] as num?)?.toInt(),
      isRequestIncoming: json['is_request_incoming'] == true,
      trustScore: biz?['trust_score'] != null
          ? TrustScore.fromApi(biz!['trust_score'])
          : null,
      factoryVerification: FactoryVerification.fromBusiness(
        biz is Map ? Map<String, dynamic>.from(biz) : null,
      ),
      scamRisk: biz?['scam_risk'] != null
          ? ScamRisk.fromApi(biz!['scam_risk'])
          : null,
      networkingConnections: () {
        final net = json['networking'];
        if (net is! Map) return 0;
        return (net['connections'] as num?)?.toInt() ?? 0;
      }(),
      networkingCountries: () {
        final net = json['networking'];
        if (net is! Map) return 0;
        return (net['countries'] as num?)?.toInt() ?? 0;
      }(),
      networkingTrust: () {
        final net = json['networking'];
        if (net is Map && net['trust'] != null) {
          return (net['trust'] as num?)?.toInt();
        }
        if (biz?['trust_score'] != null) {
          return TrustScore.fromApi(biz!['trust_score']).score;
        }
        return null;
      }(),
    );
  }
}
