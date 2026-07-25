import 'package:get/get.dart';

/// Mahsulot imkoniyatlari (xaridorga tushunarli benefit’lar).
const List<String> kProductCapabilityCodes = [
  'breathable',
  'export_quality',
  'oem_available',
  'odm_available',
  'private_label',
  'custom_logo',
  'sample_available',
  'ready_stock',
  'fast_delivery',
  'waterproof',
  'eco_friendly',
  'bulk_discount',
  'durable',
  'lightweight',
];

String productCapabilityLabel(String code) {
  final key = 'product_cap_$code';
  final tr = key.tr;
  return tr == key ? code : tr;
}

List<String> parseProductCapabilities(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  final seen = <String>{};
  for (final e in raw) {
    final code = e.toString().trim().toLowerCase().replaceAll(' ', '_');
    if (code.isEmpty || seen.contains(code)) continue;
    if (!kProductCapabilityCodes.contains(code)) continue;
    seen.add(code);
    out.add(code);
    if (out.length >= 8) break;
  }
  return out;
}
