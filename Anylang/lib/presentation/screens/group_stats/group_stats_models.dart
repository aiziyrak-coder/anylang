class GroupStatCountry {
  final String code;
  final int messageCount;
  final int memberCount;

  const GroupStatCountry({
    required this.code,
    this.messageCount = 0,
    this.memberCount = 0,
  });

  factory GroupStatCountry.fromApi(Map<String, dynamic> json) {
    return GroupStatCountry(
      code: (json['code']?.toString() ?? '').toUpperCase(),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupStatCompany {
  final int userId;
  final String companyName;
  final String? logoUrl;
  final String? country;
  final int messageCount;
  final bool verifiedBadge;

  const GroupStatCompany({
    required this.userId,
    required this.companyName,
    this.logoUrl,
    this.country,
    this.messageCount = 0,
    this.verifiedBadge = false,
  });

  factory GroupStatCompany.fromApi(Map<String, dynamic> json) {
    return GroupStatCompany(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      country: json['country']?.toString(),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      verifiedBadge: json['verified_badge'] == true,
    );
  }
}

class GroupStatProducts {
  final int userId;
  final String companyName;
  final String? logoUrl;
  final int productCount;
  final int sharedInChat;

  const GroupStatProducts({
    required this.userId,
    required this.companyName,
    this.logoUrl,
    this.productCount = 0,
    this.sharedInChat = 0,
  });

  factory GroupStatProducts.fromApi(Map<String, dynamic> json) {
    return GroupStatProducts(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      sharedInChat: (json['shared_in_chat'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupStatDeals {
  final int userId;
  final String companyName;
  final String? logoUrl;
  final int dealCount;
  final int invoiceCount;
  final int offerCount;

  const GroupStatDeals({
    required this.userId,
    required this.companyName,
    this.logoUrl,
    this.dealCount = 0,
    this.invoiceCount = 0,
    this.offerCount = 0,
  });

  factory GroupStatDeals.fromApi(Map<String, dynamic> json) {
    return GroupStatDeals(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      dealCount: (json['deal_count'] as num?)?.toInt() ?? 0,
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
      offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupStatsData {
  final int chatId;
  final int memberCount;
  final int messageCount;
  final GroupStatCountry? topCountry;
  final GroupStatCompany? topCompany;
  final GroupStatProducts? topProducts;
  final GroupStatDeals? topDeals;
  final List<GroupStatCountry> countries;
  final List<GroupStatCompany> companies;
  final List<GroupStatProducts> productsLeaders;
  final List<GroupStatDeals> dealsLeaders;

  const GroupStatsData({
    required this.chatId,
    this.memberCount = 0,
    this.messageCount = 0,
    this.topCountry,
    this.topCompany,
    this.topProducts,
    this.topDeals,
    this.countries = const [],
    this.companies = const [],
    this.productsLeaders = const [],
    this.dealsLeaders = const [],
  });

  factory GroupStatsData.fromApi(Map<String, dynamic> json) {
    T? mapOne<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
      if (raw is Map) return f(Map<String, dynamic>.from(raw));
      return null;
    }

    List<T> mapList<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    }

    return GroupStatsData(
      chatId: (json['chat_id'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      topCountry: mapOne(json['top_country'], GroupStatCountry.fromApi),
      topCompany: mapOne(json['top_company'], GroupStatCompany.fromApi),
      topProducts: mapOne(json['top_products'], GroupStatProducts.fromApi),
      topDeals: mapOne(json['top_deals'], GroupStatDeals.fromApi),
      countries: mapList(json['countries'], GroupStatCountry.fromApi),
      companies: mapList(json['companies'], GroupStatCompany.fromApi),
      productsLeaders:
          mapList(json['products_leaders'], GroupStatProducts.fromApi),
      dealsLeaders: mapList(json['deals_leaders'], GroupStatDeals.fromApi),
    );
  }
}
