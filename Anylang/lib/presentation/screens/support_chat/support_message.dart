class SupportMessage {
  final String id;
  final String text;
  final bool isOutgoing;
  final DateTime at;
  final bool pending;
  final bool failed;

  const SupportMessage({
    required this.id,
    required this.text,
    required this.isOutgoing,
    required this.at,
    this.pending = false,
    this.failed = false,
  });

  SupportMessage copyWith({
    String? text,
    bool? pending,
    bool? failed,
  }) {
    return SupportMessage(
      id: id,
      text: text ?? this.text,
      isOutgoing: isOutgoing,
      at: at,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
    );
  }
}
