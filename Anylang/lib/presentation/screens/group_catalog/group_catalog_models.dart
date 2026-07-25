class GroupCatalogProduct {
  final int? messageId;
  final int? productId;
  final String title;
  final String? price;
  final String? imageUrl;
  final String? subtitle;
  final String source;
  final int? senderId;
  final String? senderName;

  const GroupCatalogProduct({
    this.messageId,
    this.productId,
    required this.title,
    this.price,
    this.imageUrl,
    this.subtitle,
    this.source = 'product',
    this.senderId,
    this.senderName,
  });

  factory GroupCatalogProduct.fromApi(Map<String, dynamic> json) {
    return GroupCatalogProduct(
      messageId: (json['message_id'] as num?)?.toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      title: json['title']?.toString() ?? '',
      price: json['price']?.toString(),
      imageUrl: json['image_url']?.toString(),
      subtitle: json['subtitle']?.toString(),
      source: json['source']?.toString() ?? 'product',
      senderId: (json['sender_id'] as num?)?.toInt(),
      senderName: json['sender_name']?.toString(),
    );
  }
}

class GroupCatalogDocument {
  final int messageId;
  final String filename;
  final String? url;
  final int? size;
  final String? ext;
  final int? senderId;
  final String? senderName;

  const GroupCatalogDocument({
    required this.messageId,
    required this.filename,
    this.url,
    this.size,
    this.ext,
    this.senderId,
    this.senderName,
  });

  factory GroupCatalogDocument.fromApi(Map<String, dynamic> json) {
    return GroupCatalogDocument(
      messageId: (json['message_id'] as num?)?.toInt() ?? 0,
      filename: json['filename']?.toString() ?? 'file',
      url: json['url']?.toString(),
      size: (json['size'] as num?)?.toInt(),
      ext: json['ext']?.toString(),
      senderId: (json['sender_id'] as num?)?.toInt(),
      senderName: json['sender_name']?.toString(),
    );
  }
}

class GroupCatalogCompany {
  final int userId;
  final String companyName;
  final String? logoUrl;
  final String? country;
  final String? businessRole;
  final bool verifiedBadge;
  final String? website;
  final String? description;
  final String source;
  final int? messageId;

  const GroupCatalogCompany({
    required this.userId,
    required this.companyName,
    this.logoUrl,
    this.country,
    this.businessRole,
    this.verifiedBadge = false,
    this.website,
    this.description,
    this.source = 'member',
    this.messageId,
  });

  factory GroupCatalogCompany.fromApi(Map<String, dynamic> json) {
    return GroupCatalogCompany(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      country: json['country']?.toString(),
      businessRole: json['business_role']?.toString(),
      verifiedBadge: json['verified_badge'] == true,
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      source: json['source']?.toString() ?? 'member',
      messageId: (json['message_id'] as num?)?.toInt(),
    );
  }
}

class GroupCatalogData {
  final int chatId;
  final List<GroupCatalogProduct> products;
  final List<GroupCatalogDocument> documents;
  final List<GroupCatalogCompany> companies;
  final Map<String, int> counts;

  const GroupCatalogData({
    required this.chatId,
    this.products = const [],
    this.documents = const [],
    this.companies = const [],
    this.counts = const {},
  });

  factory GroupCatalogData.fromApi(Map<String, dynamic> json) {
    final countsRaw = json['counts'];
    final counts = <String, int>{};
    if (countsRaw is Map) {
      countsRaw.forEach((k, v) {
        if (v is num) counts['$k'] = v.toInt();
      });
    }
    return GroupCatalogData(
      chatId: (json['chat_id'] as num?)?.toInt() ?? 0,
      products: (json['products'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => GroupCatalogProduct.fromApi(Map<String, dynamic>.from(e)))
          .toList(),
      documents: (json['documents'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => GroupCatalogDocument.fromApi(Map<String, dynamic>.from(e)))
          .toList(),
      companies: (json['companies'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => GroupCatalogCompany.fromApi(Map<String, dynamic>.from(e)))
          .toList(),
      counts: counts,
    );
  }
}
