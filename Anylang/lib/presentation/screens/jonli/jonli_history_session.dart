/// Jonli tarixidagi bitta sessiya qisqacha.
class JonliHistorySession {
  final int id;
  final String myLanguage;
  final String otherLanguage;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int turnCount;
  final String? preview;

  const JonliHistorySession({
    required this.id,
    required this.myLanguage,
    required this.otherLanguage,
    required this.startedAt,
    this.endedAt,
    this.turnCount = 0,
    this.preview,
  });

  factory JonliHistorySession.fromJson(Map<String, dynamic> json) {
    final started = DateTime.tryParse('${json['started_at']}')?.toLocal() ??
        DateTime.now();
    final endedRaw = json['ended_at'];
    return JonliHistorySession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      myLanguage: json['my_language']?.toString() ?? '',
      otherLanguage: json['other_language']?.toString() ?? '',
      startedAt: started,
      endedAt: endedRaw == null
          ? null
          : DateTime.tryParse('$endedRaw')?.toLocal(),
      turnCount: (json['turn_count'] as num?)?.toInt() ?? 0,
      preview: json['preview']?.toString(),
    );
  }
}
