import '../../../data/core/mappers.dart';

class MarketInsight {
  final String country;
  final String topic;
  final String trend;
  final String message;
  final double confidence;
  final String signal;

  const MarketInsight({
    required this.country,
    required this.message,
    this.topic = '',
    this.trend = 'demand_up',
    this.confidence = 0.5,
    this.signal = 'rules',
  });

  factory MarketInsight.fromApi(Map<String, dynamic> json) {
    return MarketInsight(
      country: (json['country'] as String?)?.trim().toUpperCase() ?? '',
      topic: (json['topic'] as String?)?.trim() ?? '',
      trend: (json['trend'] as String?)?.trim() ?? 'demand_up',
      message: (json['message'] as String?)?.trim() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      signal: (json['signal'] as String?)?.trim() ?? 'rules',
    );
  }
}

class MarketAnalyticsResult {
  final String focusSummary;
  final List<MarketInsight> items;
  final String generatedBy;

  const MarketAnalyticsResult({
    this.focusSummary = '',
    this.items = const [],
    this.generatedBy = 'rules',
  });

  factory MarketAnalyticsResult.fromApi(dynamic raw) {
    final map = asMap(raw);
    if (map == null) return const MarketAnalyticsResult();
    final items = <MarketInsight>[];
    final list = map['items'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          items.add(MarketInsight.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    return MarketAnalyticsResult(
      focusSummary: (map['focus_summary'] as String?)?.trim() ?? '',
      items: items,
      generatedBy: (map['generated_by'] as String?) ?? 'rules',
    );
  }
}
