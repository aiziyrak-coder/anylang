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
  final bool documentsVerified;
  final String verificationStatus;
  final String flagAsset;
  final String country;
  final String role;
  final String phone;
  final String? experience;
  final String? website;
  final String? bio;
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
  final double? rating;
  final int reviewsCount;
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
    this.documentsVerified = false,
    this.verificationStatus = 'none',
    this.experience,
    this.website,
    this.bio,
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
    this.rating,
    this.reviewsCount = 0,
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
    bool isBusiness = false,
    String? country,
    String? role,
    bool verified = false,
    List<String> keywords = const [],
    int listings = 0,
    int networkingCountries = 0,
    int? networkingTrust,
    String friendshipStatus = 'none',
    String riskLevel = 'none',
    bool isScammer = false,
  }) {
    final trimmed = name.trim().isEmpty ? 'User' : name.trim();
    final countryCode = (country ?? '').trim();
    String roleKey = '';
    final roleRaw = (role ?? '').trim();
    if (roleRaw.isNotEmpty) {
      final lower = roleRaw.toLowerCase();
      if (lower.startsWith('business_role_')) {
        roleKey = lower;
      } else {
        roleKey = 'business_role_$lower';
      }
    }
    final level = isScammer
        ? 'high'
        : (riskLevel.trim().isEmpty ? 'none' : riskLevel.trim().toLowerCase());
    final showRisk = isScammer || level == 'high' || level == 'medium';
    final trust = networkingTrust;
    return UserProfilePayload(
      id: id,
      business: isBusiness,
      name: trimmed,
      initial: initial ?? initialsOf(trimmed),
      avatarGradient: avatarGradient ?? avatarGradientFor(id),
      flagAsset: countryCode.isEmpty ? '' : flagAssetForCountry(countryCode),
      country: countryCode.isEmpty ? '' : formatCountryName(countryCode),
      role: roleKey,
      phone: '',
      avatarUrl: avatarUrl,
      existingChatId: existingChatId,
      verified: verified,
      documentsVerified: verified,
      verificationStatus: verified ? 'approved' : 'none',
      keywords: keywords,
      listings: listings,
      networkingCountries: networkingCountries,
      networkingTrust: trust,
      friendshipStatus: friendshipStatus,
      trustScore: trust == null
          ? null
          : TrustScore(
              score: trust.clamp(0, 100),
              level: trust >= 70
                  ? 'high'
                  : (trust >= 40 ? 'medium' : 'low'),
            ),
      scamRisk: showRisk
          ? ScamRisk(
              riskLevel: level,
              riskScore: isScammer ? 85 : (level == 'high' ? 70 : 45),
              showWarning: true,
              message: isScammer ? 'scammer' : level,
            )
          : null,
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
      bio: (biz?['bio'] as String?)?.trim(),
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
      documentsVerified: biz?['documents_verified'] == true ||
          json['verified_badge'] == true,
      verificationStatus: () {
        if (biz?['documents_verified'] == true ||
            json['verified_badge'] == true) {
          return 'approved';
        }
        return (biz?['verification_status'] as String?) ?? 'none';
      }(),
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
      rating: () {
        final top = (json['rating'] as num?)?.toDouble();
        if (top != null) return top;
        final stats = biz?['stats'];
        if (stats is Map) return (stats['rating'] as num?)?.toDouble();
        return (biz?['rating'] as num?)?.toDouble();
      }(),
      reviewsCount: () {
        final top = (json['reviews_count'] as num?)?.toInt();
        if (top != null) return top;
        final stats = biz?['stats'];
        if (stats is Map) {
          return (stats['reviews_count'] as num?)?.toInt() ?? 0;
        }
        return (biz?['reviews_count'] as num?)?.toInt() ?? 0;
      }(),
    );
  }
}
