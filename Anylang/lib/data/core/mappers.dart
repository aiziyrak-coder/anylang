import 'package:flutter/material.dart';

import '../../presentation/ui/theme/colors.dart';
import '../../presentation/ui/theme/gradients.dart';

final List<LinearGradient> kAvatarGradients = [
  avatarTealGradient,
  avatarOliveGradient,
  avatarMaroonGradient,
  avatarGreenGradient,
  avatarSlateGradient,
  avatarBrownGradient,
];

final List<LinearGradient> kProductGradients = [
  prodBrownGradient,
  prodTealGradient,
  prodBlueGradient,
  prodPurpleGradient,
  prodOliveGradient,
  prodMaroonGradient,
];

LinearGradient avatarGradientFor(int id) =>
    kAvatarGradients[id.abs() % kAvatarGradients.length];

LinearGradient productGradientFor(int id) =>
    kProductGradients[id.abs() % kProductGradients.length];

Color initialColorFor(int id) => id.isEven ? kLime : kAvatarFg;

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String formatChatTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Kecha';
  }
  return '${local.day}.${local.month}';
}

String formatViews(int n) {
  if (n >= 1000) {
    final v = n / 1000;
    return v >= 10 ? '${v.toStringAsFixed(0)}k' : '${v.toStringAsFixed(1)}k';
  }
  return '$n';
}

String formatPrice(String price, String currency) {
  final symbol = switch (currency) {
    'USD' => '\$',
    'EUR' => '€',
    'RUB' => '₽',
    'UZS' => "so'm ",
    _ => '$currency ',
  };
  return '$symbol$price';
}

String formatNumber(String number) {
  if (number.length != 7) return number;
  return '${number.substring(0, 3)} ${number.substring(3, 5)} ${number.substring(5)}';
}

Map<String, dynamic>? asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}

List<dynamic> asList(dynamic data, [String key = 'items']) {
  if (data is List) return data;
  final map = asMap(data);
  final items = map?[key];
  if (items is List) return items;
  return const [];
}
