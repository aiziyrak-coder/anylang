import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';
import '../../ui/trust_score.dart';
import '../../ui/factory_verification.dart';
import '../../ui/scam_risk.dart';
import 'profile_insights.dart';

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

class FactoryMediaItem {
  final int id;
  final String url;

  const FactoryMediaItem({required this.id, required this.url});

  bool get isVideo {
    final u = url.toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.webm') ||
        u.contains('.m3u8');
  }
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
  /// Business hujjat verifikatsiyasi (admin tasdiqlagan).
  final bool documentsVerified;
  /// none | draft | pending | approved | rejected
  final String verificationStatus;
  final String flagAsset;
  /// ISO alpha-2 (API uchun).
  final String countryCode;
  /// Ko'rinadigan nom (Oʻzbekiston).
  final String country;
  /// Formatlangan AnyLang ID (123 45 67).
  final String? username;
  /// Xom 7 xonali raqam.
  final String anylangNumber;
  /// `@1234567` ko'rinishi.
  final String handle;
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
  final int reviewsCount;
  final int countriesCount;
  final List<String> exportCountryCodes;
  final int? foundedYear;
  final int? exportYears;
  final String? moq;
  final String? productionCapacity;
  final String? leadTime;
  final List<String> incoterms;
  final List<String> paymentMethods;
  final List<String> certificates;
  final List<FactoryMediaItem> factoryMedia;
  final List<OwnListing> listings;
  final String? avatarUrl;
  final String? email;
  /// Qisqa bio (faqat biznes yozadi, max 300).
  final String? bio;
  final TrustScore? trustScore;
  final FactoryVerification factoryVerification;
  final ScamRisk? scamRisk;
  final int networkingConnections;
  final int networkingCountries;
  final int? networkingTrust;
  final ProfileInsights insights;

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
    this.documentsVerified = false,
    this.verificationStatus = 'none',
    this.username,
    this.anylangNumber = '',
    this.handle = '',
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
    this.reviewsCount = 0,
    this.countriesCount = 0,
    this.exportCountryCodes = const [],
    this.foundedYear,
    this.exportYears,
    this.moq,
    this.productionCapacity,
    this.leadTime,
    this.incoterms = const [],
    this.paymentMethods = const [],
    this.certificates = const [],
    this.factoryMedia = const [],
    this.listings = const [],
    this.avatarUrl,
    this.email,
    this.bio,
    this.trustScore,
    this.factoryVerification = const FactoryVerification(),
    this.scamRisk,
    this.networkingConnections = 0,
    this.networkingCountries = 0,
    this.networkingTrust,
    this.insights = const ProfileInsights(),
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
    final stats = biz?['stats'] is Map
        ? Map<String, dynamic>.from(biz!['stats'] as Map)
        : <String, dynamic>{};

    final exportCodes = <String>[];
    final rawCountries = biz?['export_countries'] ?? stats['export_countries'];
    if (rawCountries is List) {
      for (final e in rawCountries) {
        final code = e.toString().trim().toUpperCase();
        if (code.length == 2) exportCodes.add(code);
      }
    }

    final factory = <FactoryMediaItem>[];
    final factoryRaw = biz?['factory_images'];
    if (factoryRaw is List) {
      for (final e in factoryRaw) {
        if (e is! Map) continue;
        final fid = (e['id'] as num?)?.toInt() ?? 0;
        final url = e['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          factory.add(FactoryMediaItem(id: fid, url: url));
        }
      }
    }

    final founded = (biz?['founded_year'] as num?)?.toInt() ??
        (stats['founded_year'] as num?)?.toInt();
    final exportYears = (stats['export_years'] as num?)?.toInt() ??
        (founded != null ? (DateTime.now().year - founded).clamp(0, 200) : null);

    final net = json['networking'];
    final netMap = net is Map ? Map<String, dynamic>.from(net) : null;
    final trustFromBiz = biz?['trust_score'] != null
        ? TrustScore.fromApi(biz!['trust_score'])
        : null;

    final insightsRaw = json['profile_insights'];
    final insights = ProfileInsights.fromApi(
      insightsRaw is Map ? Map<String, dynamic>.from(insightsRaw) : null,
    );

    final formattedId = number.isEmpty ? null : formatNumber(number);
    final viewsFromStats = (stats['total_views'] as num?)?.toInt();
    final viewsTotal = viewsFromStats ?? insights.totalViews;
    final ratingValue =
        (stats['rating'] as num?)?.toDouble() ?? insights.rating;
    final listings =
        (stats['listings_count'] as num?)?.toInt() ?? insights.listingsCount;

    return ProfileAccount(
      id: id,
      isBusiness: isBusiness,
      name: displayName,
      initial: initialsOf(displayName),
      avatarGradient: avatarGradientFor(id),
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
      flagAsset: flagAssetForCountry(countryCode),
      countryCode: countryCode.toUpperCase(),
      country: formatCountryName(countryCode),
      username: formattedId,
      anylangNumber: number,
      handle: number.isEmpty ? '' : '@$number',
      nativeLanguage: formatLanguagesBadge(languageCodesFromApi(json)),
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
      listingsCount: listings,
      viewsCount: formatViews(viewsTotal),
      rating: ratingValue,
      reviewsCount: (stats['reviews_count'] as num?)?.toInt() ?? 0,
      countriesCount: (stats['countries_count'] as num?)?.toInt() ??
          exportCodes.length,
      exportCountryCodes: exportCodes,
      foundedYear: founded,
      exportYears: exportYears,
      moq: (biz?['moq'] as String?)?.trim(),
      productionCapacity: (biz?['production_capacity'] as String?)?.trim(),
      leadTime: (biz?['lead_time'] as String?)?.trim(),
      incoterms: (biz?['incoterms'] is List)
          ? (biz!['incoterms'] as List).map((e) => e.toString()).toList()
          : const [],
      paymentMethods: (biz?['payment_methods'] is List)
          ? (biz!['payment_methods'] as List).map((e) => e.toString()).toList()
          : const [],
      certificates: (biz?['certificates'] is List)
          ? (biz!['certificates'] as List).map((e) => e.toString()).toList()
          : const [],
      factoryMedia: factory,
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
      bio: () {
        final fromBiz = (biz?['bio'] as String?)?.trim();
        if (fromBiz != null && fromBiz.isNotEmpty) return fromBiz;
        final top = (json['bio'] as String?)?.trim();
        return (top != null && top.isNotEmpty) ? top : null;
      }(),
      trustScore: trustFromBiz,
      factoryVerification: FactoryVerification.fromBusiness(
        biz is Map ? Map<String, dynamic>.from(biz) : null,
      ),
      scamRisk: biz?['scam_risk'] != null
          ? ScamRisk.fromApi(biz!['scam_risk'])
          : null,
      networkingConnections: (netMap?['connections'] as num?)?.toInt() ?? 0,
      networkingCountries: (netMap?['countries'] as num?)?.toInt() ?? 0,
      networkingTrust: (netMap?['trust'] as num?)?.toInt() ??
          trustFromBiz?.score ??
          insights.trustPercent,
      insights: insights,
    );
  }

  ProfileAccount copyWith({
    List<OwnListing>? listings,
    int? listingsCount,
    String? avatarUrl,
    String? name,
    String? initial,
    String? email,
    String? bio,
    bool clearBio = false,
  }) {
    return ProfileAccount(
      id: id,
      isBusiness: isBusiness,
      name: name ?? this.name,
      initial: initial ?? this.initial,
      avatarGradient: avatarGradient,
      verified: verified,
      documentsVerified: documentsVerified,
      verificationStatus: verificationStatus,
      flagAsset: flagAsset,
      countryCode: countryCode,
      country: country,
      username: username,
      anylangNumber: anylangNumber,
      handle: handle,
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
      reviewsCount: reviewsCount,
      countriesCount: countriesCount,
      exportCountryCodes: exportCountryCodes,
      foundedYear: foundedYear,
      exportYears: exportYears,
      moq: moq,
      productionCapacity: productionCapacity,
      leadTime: leadTime,
      incoterms: incoterms,
      paymentMethods: paymentMethods,
      certificates: certificates,
      factoryMedia: factoryMedia,
      listings: listings ?? this.listings,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bio: clearBio ? null : (bio ?? this.bio),
      trustScore: trustScore,
      factoryVerification: factoryVerification,
      scamRisk: scamRisk,
      networkingConnections: networkingConnections,
      networkingCountries: networkingCountries,
      networkingTrust: networkingTrust,
      insights: insights,
    );
  }
}
