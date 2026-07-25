class DealDocument {
  final int messageId;
  final String title;
  final String kind;
  final String? url;

  const DealDocument({
    required this.messageId,
    required this.title,
    required this.kind,
    this.url,
  });

  factory DealDocument.fromApi(Map<String, dynamic> json) {
    return DealDocument(
      messageId: (json['message_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'file',
      url: json['url']?.toString(),
    );
  }
}

class DealDocumentCandidate {
  final int messageId;
  final String title;
  final String kind;
  final String? url;

  const DealDocumentCandidate({
    required this.messageId,
    required this.title,
    required this.kind,
    this.url,
  });

  factory DealDocumentCandidate.fromApi(Map<String, dynamic> json) {
    return DealDocumentCandidate(
      messageId: (json['message_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'file',
      url: json['url']?.toString(),
    );
  }
}

class DealData {
  final int id;
  final int chatId;
  final String product;
  final String price;
  final String currency;
  final String quantity;
  final String unit;
  final String delivery;
  final String payment;
  final String status;
  final int version;
  final List<DealDocument> documents;
  final List<int> acceptedBy;
  final int acceptedCount;
  final bool viewerAccepted;
  final int createdBy;

  const DealData({
    required this.id,
    required this.chatId,
    required this.product,
    required this.price,
    required this.currency,
    required this.quantity,
    required this.unit,
    required this.delivery,
    required this.payment,
    required this.status,
    required this.version,
    required this.documents,
    required this.acceptedBy,
    required this.acceptedCount,
    required this.viewerAccepted,
    required this.createdBy,
  });

  factory DealData.fromApi(Map<String, dynamic> json) {
    final docsRaw = json['documents'];
    final docs = <DealDocument>[];
    if (docsRaw is List) {
      for (final e in docsRaw) {
        if (e is Map) {
          docs.add(DealDocument.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    final acceptedRaw = json['accepted_by'];
    final accepted = <int>[];
    if (acceptedRaw is List) {
      for (final e in acceptedRaw) {
        if (e is num) accepted.add(e.toInt());
      }
    }
    return DealData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      chatId: (json['chat_id'] as num?)?.toInt() ?? 0,
      product: json['product']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      delivery: json['delivery']?.toString() ?? '',
      payment: json['payment']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      version: (json['version'] as num?)?.toInt() ?? 1,
      documents: docs,
      acceptedBy: accepted,
      acceptedCount: (json['accepted_count'] as num?)?.toInt() ?? accepted.length,
      viewerAccepted: json['viewer_accepted'] == true,
      createdBy: (json['created_by'] as num?)?.toInt() ?? 0,
    );
  }
}
