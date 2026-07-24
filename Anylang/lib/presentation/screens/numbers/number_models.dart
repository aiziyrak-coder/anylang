class NumberGroupInfo {
  final int id;
  final String name;
  final String price;
  final String currency;
  final String? bonusPlan;
  final int? bonusMonths;
  final int availableCount;

  const NumberGroupInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.bonusPlan,
    this.bonusMonths,
    this.availableCount = 0,
  });

  bool get isFree {
    final p = double.tryParse(price) ?? 0;
    return p <= 0;
  }

  String get priceLabel {
    if (isFree) return '0';
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : '$currency ';
    return '$symbol$price';
  }

  factory NumberGroupInfo.fromApi(Map<String, dynamic> json) {
    return NumberGroupInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'USD',
      bonusPlan: json['bonus_plan']?.toString(),
      bonusMonths: (json['bonus_duration_months'] as num?)?.toInt(),
      availableCount: (json['available_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogNumber {
  final String number;
  final NumberGroupInfo group;
  final bool available;

  const CatalogNumber({
    required this.number,
    required this.group,
    this.available = true,
  });

  factory CatalogNumber.fromApi(Map<String, dynamic> json) {
    final g = json['group'];
    return CatalogNumber(
      number: json['number']?.toString() ?? '',
      group: NumberGroupInfo.fromApi(
        g is Map ? Map<String, dynamic>.from(g) : <String, dynamic>{},
      ),
      available: json['is_available'] != false,
    );
  }
}

class MyNumberInfo {
  final String number;
  final NumberGroupInfo? group;
  final bool canChangeFree;
  final int cooldownSeconds;
  final int cooldownDays;

  const MyNumberInfo({
    required this.number,
    this.group,
    this.canChangeFree = true,
    this.cooldownSeconds = 0,
    this.cooldownDays = 90,
  });

  factory MyNumberInfo.fromApi(Map<String, dynamic> json) {
    final g = json['group'];
    return MyNumberInfo(
      number: json['number']?.toString() ?? '',
      group: g is Map
          ? NumberGroupInfo.fromApi(Map<String, dynamic>.from(g))
          : null,
      canChangeFree: json['can_change_free'] != false,
      cooldownSeconds: (json['cooldown_seconds'] as num?)?.toInt() ?? 0,
      cooldownDays: (json['cooldown_days'] as num?)?.toInt() ?? 90,
    );
  }
}
