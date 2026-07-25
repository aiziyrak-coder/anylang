import '../../../data/core/mappers.dart';

class AiMatchCompany {
  final int id;
  final String name;
  final String? country;
  final String? businessRole;
  final String? logoUrl;

  const AiMatchCompany({
    required this.id,
    required this.name,
    this.country,
    this.businessRole,
    this.logoUrl,
  });

  factory AiMatchCompany.fromApi(Map<String, dynamic> json) {
    return AiMatchCompany(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      country: (json['country'] as String?)?.trim(),
      businessRole: (json['business_role'] as String?)?.trim(),
      logoUrl: (json['logo_url'] as String?)?.trim(),
    );
  }
}

class AiMatchInsight {
  final String country;
  final int count;
  final String message;
  final String matchType;
  final List<AiMatchCompany> sampleCompanies;

  const AiMatchInsight({
    required this.country,
    required this.count,
    required this.message,
    this.matchType = 'buyers_looking',
    this.sampleCompanies = const [],
  });

  factory AiMatchInsight.fromApi(Map<String, dynamic> json) {
    final samples = <AiMatchCompany>[];
    final raw = json['sample_companies'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          samples.add(AiMatchCompany.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    return AiMatchInsight(
      country: (json['country'] as String?)?.trim().toUpperCase() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      message: (json['message'] as String?)?.trim() ?? '',
      matchType: (json['match_type'] as String?) ?? 'buyers_looking',
      sampleCompanies: samples,
    );
  }
}

class AiMatchingResult {
  final String productSummary;
  final List<AiMatchInsight> items;
  final String generatedBy;

  const AiMatchingResult({
    this.productSummary = '',
    this.items = const [],
    this.generatedBy = 'rules',
  });

  factory AiMatchingResult.fromApi(dynamic raw) {
    final map = asMap(raw);
    if (map == null) return const AiMatchingResult();
    final items = <AiMatchInsight>[];
    final list = map['items'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          items.add(AiMatchInsight.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    return AiMatchingResult(
      productSummary: (map['product_summary'] as String?)?.trim() ?? '',
      items: items,
      generatedBy: (map['generated_by'] as String?) ?? 'rules',
    );
  }
}
