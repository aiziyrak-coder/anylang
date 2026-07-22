import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../presentation/ui/theme/colors.dart';
import '../../presentation/ui/theme/gradients.dart';
import '../local/countries_service.dart';

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

/// ISO alpha-2 → lokalizatsiyalangan davlat nomi (cache yoki kod).
String formatCountryName(String? code) {
  if (code == null || code.trim().isEmpty) return '—';
  final c = code.trim().toUpperCase();
  if (Get.isRegistered<CountriesService>()) {
    final name = Get.find<CountriesService>().displayName(c);
    if (name.isNotEmpty) return name;
  }
  return c;
}

/// ISO 639-1 → lokalizatsiya kaliti (`lang_name_uz` va h.k.).
String formatLanguageName(String? code) {
  if (code == null || code.trim().isEmpty) return '';
  final normalized = code.trim().toLowerCase().split(RegExp(r'[_-]')).first;
  final key = 'lang_name_$normalized';
  final translated = key.tr;
  return translated == key ? normalized.toUpperCase() : translated;
}

/// `2024-03-15` → "Mart 2024" (UI tili bo'yicha).
String formatMonthYear(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final month = 'month_${local.month}'.tr;
  return '$month ${local.year}';
}

/// `premium` / `basic` / `business` → ko'rinadigan nom.
String formatSubscriptionPlan(String? plan) {
  switch (plan?.toLowerCase()) {
    case 'premium':
      return 'plan_premium'.tr;
    case 'business':
      return 'plan_business'.tr;
    case 'basic':
      return 'plan_basic'.tr;
    default:
      return plan?.trim().isNotEmpty == true ? plan! : 'plan_basic'.tr;
  }
}

/// `yearly` → "12 oy", `monthly` → "1 oy"; muddatlardan hisoblash fallback.
String formatSubscriptionPeriod({
  String? billingCycle,
  DateTime? startedAt,
  DateTime? expiresAt,
}) {
  final cycle = billingCycle?.toLowerCase();
  if (cycle == 'yearly' || cycle == 'year' || cycle == 'annual') {
    return '12 ${'subscription_months_short'.tr}';
  }
  if (cycle == 'monthly' || cycle == 'month') {
    return '1 ${'subscription_months_short'.tr}';
  }
  if (startedAt != null && expiresAt != null) {
    final days = expiresAt.difference(startedAt).inDays;
    if (days > 0) {
      final months = (days / 30).round().clamp(1, 120);
      return '$months ${'subscription_months_short'.tr}';
    }
  }
  return '';
}

String formatSubscriptionLabel({
  required String? plan,
  String? billingCycle,
  DateTime? startedAt,
  DateTime? expiresAt,
}) {
  final planLabel = formatSubscriptionPlan(plan);
  final period = formatSubscriptionPeriod(
    billingCycle: billingCycle,
    startedAt: startedAt,
    expiresAt: expiresAt,
  );
  if (period.isEmpty) return planLabel;
  return '$planLabel · $period';
}

/// Bayroq asset (mavjudlar); noma'lum → UZ.
String flagAssetForCountry(String? code) {
  switch (code?.toUpperCase()) {
    case 'TR':
      return 'assets/images/flag_tr.png';
    case 'RU':
      return 'assets/images/flag_ru.png';
    case 'DE':
      return 'assets/images/flag_de.png';
    case 'ES':
      return 'assets/images/flag_es.png';
    case 'FR':
      return 'assets/images/flag_fr.png';
    case 'US':
    case 'GB':
    case 'EN':
      return 'assets/images/flag_en.png';
    case 'UZ':
    default:
      return 'assets/images/flag_uz.png';
  }
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
