class TradeAssistantMatchProduct {
  final int id;
  final String name;
  final String? price;
  final String? currency;
  final String? imageUrl;
  final int? sellerId;
  final String? sellerName;

  const TradeAssistantMatchProduct({
    required this.id,
    required this.name,
    this.price,
    this.currency,
    this.imageUrl,
    this.sellerId,
    this.sellerName,
  });

  factory TradeAssistantMatchProduct.fromApi(Map<String, dynamic> json) {
    return TradeAssistantMatchProduct(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      price: json['price']?.toString(),
      currency: json['currency']?.toString(),
      imageUrl: json['image_url']?.toString(),
      sellerId: (json['seller_id'] as num?)?.toInt(),
      sellerName: json['seller_name']?.toString(),
    );
  }

  String get priceLabel {
    final p = (price ?? '').trim();
    final c = (currency ?? '').trim();
    if (p.isEmpty) return '';
    return c.isEmpty ? p : '$p $c';
  }
}

class TradeAssistantMatchSeller {
  final int id;
  final String companyName;
  final String? country;
  final String? businessRole;
  final bool verified;
  final String? logoUrl;
  final int productsCount;

  const TradeAssistantMatchSeller({
    required this.id,
    required this.companyName,
    this.country,
    this.businessRole,
    this.verified = false,
    this.logoUrl,
    this.productsCount = 0,
  });

  factory TradeAssistantMatchSeller.fromApi(Map<String, dynamic> json) {
    return TradeAssistantMatchSeller(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      country: json['country']?.toString(),
      businessRole: json['business_role']?.toString(),
      verified: json['verified_badge'] == true,
      logoUrl: json['logo_url']?.toString(),
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TradeAssistantMessage {
  final String id;
  final String text;
  final bool isOutgoing;
  final DateTime at;
  final bool pending;
  final bool failed;
  final List<TradeAssistantMatchProduct> products;
  final List<TradeAssistantMatchSeller> sellers;
  final List<String> nextQuestions;

  const TradeAssistantMessage({
    required this.id,
    required this.text,
    required this.isOutgoing,
    required this.at,
    this.pending = false,
    this.failed = false,
    this.products = const [],
    this.sellers = const [],
    this.nextQuestions = const [],
  });
}
