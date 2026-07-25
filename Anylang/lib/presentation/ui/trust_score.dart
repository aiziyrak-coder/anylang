class TrustFactor {
  final String key;
  final int score;
  final int max;
  final int? count;
  final double? avgMinutes;
  final int? samples;
  final bool? verifiedBadge;
  final bool? documentsVerified;

  const TrustFactor({
    required this.key,
    required this.score,
    required this.max,
    this.count,
    this.avgMinutes,
    this.samples,
    this.verifiedBadge,
    this.documentsVerified,
  });

  factory TrustFactor.fromApi(Map<String, dynamic> json) {
    return TrustFactor(
      key: json['key']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt(),
      avgMinutes: (json['avg_minutes'] as num?)?.toDouble(),
      samples: (json['samples'] as num?)?.toInt(),
      verifiedBadge: json['verified_badge'] as bool?,
      documentsVerified: json['documents_verified'] as bool?,
    );
  }
}

class TrustScore {
  final int score;
  final String level;
  final List<TrustFactor> breakdown;

  const TrustScore({
    required this.score,
    required this.level,
    this.breakdown = const [],
  });

  factory TrustScore.fromApi(dynamic raw) {
    if (raw is! Map) {
      return const TrustScore(score: 0, level: 'low');
    }
    final map = Map<String, dynamic>.from(raw);
    final parts = <TrustFactor>[];
    final list = map['breakdown'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          parts.add(TrustFactor.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    return TrustScore(
      score: ((map['score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      level: map['level']?.toString() ?? 'low',
      breakdown: parts,
    );
  }
}
