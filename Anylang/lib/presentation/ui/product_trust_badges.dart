/// Mahsulot ishonch belgilari (API `trust_badges`).
class ProductTrustBadges {
  final bool factoryVerified;
  final bool iso;
  final bool tradeAssurance;
  final bool premium;

  const ProductTrustBadges({
    this.factoryVerified = false,
    this.iso = false,
    this.tradeAssurance = false,
    this.premium = false,
  });

  bool get hasAny =>
      factoryVerified || iso || tradeAssurance || premium;

  factory ProductTrustBadges.fromApi(dynamic raw) {
    if (raw is! Map) return const ProductTrustBadges();
    return ProductTrustBadges(
      factoryVerified: raw['factory_verified'] == true,
      iso: raw['iso'] == true,
      tradeAssurance: raw['trade_assurance'] == true,
      premium: raw['premium'] == true,
    );
  }
}
