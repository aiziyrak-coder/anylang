class TrustFactor {
  final String key;
  final int score;
  final int max;
  final int gap;
  final String action;
  final bool complete;
  final int? count;
  final int? premiumCount;
  final double? avgMinutes;
  final int? samples;
  final bool? verifiedBadge;
  final bool? documentsVerified;
  final bool? factoryVerified;
  final bool? inspectionPassed;

  const TrustFactor({
    required this.key,
    required this.score,
    required this.max,
    this.gap = 0,
    this.action = 'none',
    this.complete = false,
    this.count,
    this.premiumCount,
    this.avgMinutes,
    this.samples,
    this.verifiedBadge,
    this.documentsVerified,
    this.factoryVerified,
    this.inspectionPassed,
  });

  factory TrustFactor.fromApi(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toInt() ?? 0;
    final max = (json['max'] as num?)?.toInt() ?? 0;
    final gapRaw = (json['gap'] as num?)?.toInt();
    final gap = gapRaw ?? (max - score).clamp(0, max);
    return TrustFactor(
      key: json['key']?.toString() ?? '',
      score: score,
      max: max,
      gap: gap,
      action: json['action']?.toString() ?? 'none',
      complete: json['complete'] == true || gap == 0,
      count: (json['count'] as num?)?.toInt(),
      premiumCount: (json['premium_count'] as num?)?.toInt(),
      avgMinutes: (json['avg_minutes'] as num?)?.toDouble(),
      samples: (json['samples'] as num?)?.toInt(),
      verifiedBadge: json['verified_badge'] as bool?,
      documentsVerified: json['documents_verified'] as bool?,
      factoryVerified: json['factory_verified'] as bool?,
      inspectionPassed: json['inspection_passed'] as bool?,
    );
  }
}

class TrustScore {
  final int score;
  final String level;
  final int nextGain;
  final List<TrustFactor> breakdown;

  const TrustScore({
    required this.score,
    required this.level,
    this.nextGain = 0,
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
    final next = (map['next_gain'] as num?)?.toInt();
    final computedNext = next ??
        (parts.isEmpty
            ? 0
            : parts.map((p) => p.gap).fold<int>(0, (a, b) => a > b ? a : b));
    return TrustScore(
      score: ((map['score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      level: map['level']?.toString() ?? 'low',
      nextGain: computedNext.clamp(0, 100),
      breakdown: parts,
    );
  }
}
