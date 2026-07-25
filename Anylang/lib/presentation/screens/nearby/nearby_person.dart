import '../../../data/core/mappers.dart';

class NearbyPerson {
  final int id;
  final String name;
  final String initial;
  final String? avatarUrl;
  final String languageCode;
  final String? countryCode;
  final bool verified;
  final bool isBusiness;
  final int distanceM;

  const NearbyPerson({
    required this.id,
    required this.name,
    required this.initial,
    required this.languageCode,
    this.avatarUrl,
    this.countryCode,
    this.verified = false,
    this.isBusiness = false,
    this.distanceM = 0,
  });

  factory NearbyPerson.fromApi(Map<String, dynamic> json) {
    final name = (json['full_name'] as String?)?.trim().isNotEmpty == true
        ? (json['full_name'] as String).trim()
        : 'User';
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return NearbyPerson(
      id: id,
      name: name,
      initial: initialsOf(name),
      avatarUrl: (json['avatar_url'] as String?)?.trim(),
      languageCode: (json['native_language'] as String?)?.trim().toLowerCase() ??
          'en',
      countryCode: (json['country'] as String?)?.trim().toUpperCase(),
      verified: json['verified_badge'] == true,
      isBusiness: json['is_business'] == true,
      distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
    );
  }

  String get distanceLabel {
    if (distanceM < 1000) return '$distanceM m';
    final km = distanceM / 1000.0;
    final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return '$text km';
  }
}
