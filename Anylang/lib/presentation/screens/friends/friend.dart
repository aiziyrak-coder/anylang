import 'package:flutter/material.dart';
import '../../../data/core/mappers.dart';
import '../../utils/formatters/time_formatter.dart';

/// Bitta do'st (Do'stlar ro'yxati elementi).
class Friend {
  final int id;
  final String initial;
  final LinearGradient avatarGradient;
  final String name;
  final String status;
  final bool online;
  final DateTime? lastSeenAt;
  final String? avatarUrl;
  final String? nativeLanguage;
  final String? number;
  final String? country;
  final String? businessRole;
  final double? rating;
  final int reviewsCount;
  final int? trust;
  final String riskLevel;
  final bool isScammer;
  final bool verified;
  final bool isBusiness;
  final List<String> keywords;
  final List<String> productCategories;
  final List<String> languages;
  final int productsCount;
  final int countriesCount;

  const Friend({
    required this.id,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.status,
    required this.online,
    this.lastSeenAt,
    this.avatarUrl,
    this.nativeLanguage,
    this.number,
    this.country,
    this.businessRole,
    this.rating,
    this.reviewsCount = 0,
    this.trust,
    this.riskLevel = 'none',
    this.isScammer = false,
    this.verified = false,
    this.isBusiness = false,
    this.keywords = const [],
    this.productCategories = const [],
    this.languages = const [],
    this.productsCount = 0,
    this.countriesCount = 0,
  });

  bool get hasRiskWarning =>
      isScammer || riskLevel == 'high' || riskLevel == 'medium';

  factory Friend.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final company = (json['company_name'] as String?)?.trim();
    final name = (company != null && company.isNotEmpty)
        ? company
        : ((json['full_name'] as String?)?.trim().isNotEmpty == true
            ? json['full_name'] as String
            : 'User');
    final online = json['is_online'] == true;
    final lang = (json['native_language'] as String?) ?? '';
    final country = json['country']?.toString();
    final role = json['business_role']?.toString();
    final rating = (json['rating'] as num?)?.toDouble();
    final verified = json['verified_badge'] == true;
    final keywords = <String>[];
    final rawKw = json['keywords'];
    if (rawKw is List) {
      for (final e in rawKw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) keywords.add(s);
      }
    }
    final categories = <String>[];
    final rawCat = json['product_categories'];
    if (rawCat is List) {
      for (final e in rawCat) {
        final s = e?.toString().trim().toLowerCase() ?? '';
        if (s.isNotEmpty) categories.add(s);
      }
    }
    final risk = (json['risk_level']?.toString() ?? 'none').toLowerCase();
    return Friend(
      id: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      name: name,
      status: online ? 'online' : (lang.isEmpty ? '' : lang),
      online: online,
      lastSeenAt: parseApiDateTime(json['last_seen_at']),
      avatarUrl: json['avatar_url'] as String?,
      nativeLanguage: lang,
      number: json['number'] as String?,
      country: country,
      businessRole: role,
      rating: rating,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      trust: (json['trust'] as num?)?.toInt(),
      riskLevel: risk,
      isScammer: json['is_scammer'] == true || risk == 'high',
      verified: verified,
      isBusiness: json['is_business'] == true,
      keywords: keywords,
      productCategories: categories,
      languages: languageCodesFromApi(json),
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
      countriesCount: (json['countries_count'] as num?)?.toInt() ?? 0,
    );
  }

  Friend copyWithOnline(bool online, {DateTime? lastSeenAt}) {
    return Friend(
      id: id,
      initial: initial,
      avatarGradient: avatarGradient,
      name: name,
      status: online ? 'online' : (nativeLanguage ?? ''),
      online: online,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      avatarUrl: avatarUrl,
      nativeLanguage: nativeLanguage,
      number: number,
      country: country,
      businessRole: businessRole,
      rating: rating,
      reviewsCount: reviewsCount,
      trust: trust,
      riskLevel: riskLevel,
      isScammer: isScammer,
      verified: verified,
      isBusiness: isBusiness,
      keywords: keywords,
      productCategories: productCategories,
      languages: languages,
      productsCount: productsCount,
      countriesCount: countriesCount,
    );
  }
}
