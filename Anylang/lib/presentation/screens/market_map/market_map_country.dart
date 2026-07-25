class MarketMapCompany {
  final int id;
  final String companyName;
  final bool verified;
  final bool factoryVerified;
  final int productCount;

  const MarketMapCompany({
    required this.id,
    required this.companyName,
    this.verified = false,
    this.factoryVerified = false,
    this.productCount = 0,
  });

  factory MarketMapCompany.fromApi(Map<String, dynamic> json) {
    return MarketMapCompany(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: (json['company_name'] as String?)?.trim().isNotEmpty == true
          ? (json['company_name'] as String).trim()
          : 'Company',
      verified: json['verified'] == true,
      factoryVerified: json['factory_verified'] == true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarketMapCountry {
  final String country;
  final int manufacturerCount;
  final int productCount;
  final List<MarketMapCompany> companies;

  const MarketMapCountry({
    required this.country,
    required this.manufacturerCount,
    required this.productCount,
    this.companies = const [],
  });

  factory MarketMapCountry.fromApi(Map<String, dynamic> json) {
    final raw = json['companies'];
    final companies = <MarketMapCompany>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          companies.add(
            MarketMapCompany.fromApi(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return MarketMapCountry(
      country: ((json['country'] as String?) ?? '').toUpperCase(),
      manufacturerCount: (json['manufacturer_count'] as num?)?.toInt() ?? 0,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      companies: companies,
    );
  }
}
