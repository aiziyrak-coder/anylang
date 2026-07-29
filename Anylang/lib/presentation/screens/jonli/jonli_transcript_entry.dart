/// Jonli muloqot — bitta gap (transkript yozuvi).
class JonliTranscriptEntry {
  final int? id;
  final String clientTurnId;
  final bool isMe;
  final String original;
  final String translated;
  final DateTime at;
  final bool pending;
  final bool failed;
  final bool fromCamera;
  /// Fail bo‘lganda qayta yuborish uchun lokal audio.
  final String? audioPath;

  const JonliTranscriptEntry({
    this.id,
    required this.clientTurnId,
    required this.isMe,
    required this.original,
    required this.translated,
    required this.at,
    this.pending = false,
    this.failed = false,
    this.fromCamera = false,
    this.audioPath,
  });

  JonliTranscriptEntry copyWith({
    int? id,
    String? clientTurnId,
    bool? isMe,
    String? original,
    String? translated,
    DateTime? at,
    bool? pending,
    bool? failed,
    bool? fromCamera,
    String? audioPath,
    bool clearAudioPath = false,
  }) {
    return JonliTranscriptEntry(
      id: id ?? this.id,
      clientTurnId: clientTurnId ?? this.clientTurnId,
      isMe: isMe ?? this.isMe,
      original: original ?? this.original,
      translated: translated ?? this.translated,
      at: at ?? this.at,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      fromCamera: fromCamera ?? this.fromCamera,
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
    );
  }
}
