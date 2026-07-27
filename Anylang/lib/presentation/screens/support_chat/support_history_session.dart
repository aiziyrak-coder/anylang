class SupportHistorySession {
  final int id;
  final String status;
  final String? preview;
  final DateTime? updatedAt;
  final int? rating;

  const SupportHistorySession({
    required this.id,
    required this.status,
    this.preview,
    this.updatedAt,
    this.rating,
  });

  bool get isActive => status == 'active';

  factory SupportHistorySession.fromJson(Map<String, dynamic> json) {
    return SupportHistorySession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'completed',
      preview: json['preview']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      rating: (json['rating'] as num?)?.toInt(),
    );
  }
}
