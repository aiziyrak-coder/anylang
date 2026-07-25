import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Tezkor biznes tipi — avatar yonida.
enum BusinessBadgeKind { factory_, logistics, trader, company, it }

class BusinessBadgeInfo {
  final BusinessBadgeKind kind;
  final String emoji;
  final String labelKey;

  const BusinessBadgeInfo({
    required this.kind,
    required this.emoji,
    required this.labelKey,
  });

  String get label => labelKey.tr;
}

BusinessBadgeInfo? resolveBusinessBadge({
  String? businessRole,
  List<String> keywords = const [],
  bool isBusiness = false,
}) {
  final role = (businessRole ?? '').trim().toLowerCase();
  final blob = [
    role,
    ...keywords.map((k) => k.trim().toLowerCase()),
  ].where((s) => s.isNotEmpty).join(' ');

  if (_matchesIt(blob)) {
    return const BusinessBadgeInfo(
      kind: BusinessBadgeKind.it,
      emoji: '👨‍💻',
      labelKey: 'business_badge_it',
    );
  }

  switch (role) {
    case 'manufacturer':
      return const BusinessBadgeInfo(
        kind: BusinessBadgeKind.factory_,
        emoji: '🏭',
        labelKey: 'business_badge_factory',
      );
    case 'distributor':
      return const BusinessBadgeInfo(
        kind: BusinessBadgeKind.logistics,
        emoji: '🚚',
        labelKey: 'business_badge_logistics',
      );
    case 'retail':
      return const BusinessBadgeInfo(
        kind: BusinessBadgeKind.trader,
        emoji: '💼',
        labelKey: 'business_badge_trader',
      );
    case 'service':
      return const BusinessBadgeInfo(
        kind: BusinessBadgeKind.company,
        emoji: '🏢',
        labelKey: 'business_badge_company',
      );
  }

  if (_matchesFactory(blob)) {
    return const BusinessBadgeInfo(
      kind: BusinessBadgeKind.factory_,
      emoji: '🏭',
      labelKey: 'business_badge_factory',
    );
  }
  if (_matchesLogistics(blob)) {
    return const BusinessBadgeInfo(
      kind: BusinessBadgeKind.logistics,
      emoji: '🚚',
      labelKey: 'business_badge_logistics',
    );
  }
  if (_matchesTrader(blob)) {
    return const BusinessBadgeInfo(
      kind: BusinessBadgeKind.trader,
      emoji: '💼',
      labelKey: 'business_badge_trader',
    );
  }
  if (isBusiness || role.isNotEmpty) {
    return const BusinessBadgeInfo(
      kind: BusinessBadgeKind.company,
      emoji: '🏢',
      labelKey: 'business_badge_company',
    );
  }
  return null;
}

bool _matchesIt(String blob) {
  const keys = [
    'it',
    'software',
    'saas',
    'tech',
    'digital',
    'developer',
    'programming',
    'программ',
    'айти',
    'dastur',
    'it-kompaniya',
    'it company',
  ];
  return keys.any((k) => blob.contains(k));
}

bool _matchesFactory(String blob) {
  const keys = [
    'factory',
    'manufacturer',
    'fabric',
    'zavod',
    'завод',
    'fabrika',
    'фабрика',
    'ishlab',
    'производ',
  ];
  return keys.any((k) => blob.contains(k));
}

bool _matchesLogistics(String blob) {
  const keys = [
    'logistic',
    'logistics',
    'distributor',
    'shipping',
    'freight',
    'transport',
    'cargo',
    'logistika',
    'логистик',
    'yetkazib',
  ];
  return keys.any((k) => blob.contains(k));
}

bool _matchesTrader(String blob) {
  const keys = [
    'trader',
    'trading',
    'retail',
    'wholesale',
    'merchant',
    'savdo',
    'treyder',
    'трейдер',
    'ритейл',
    'опт',
  ];
  return keys.any((k) => blob.contains(k));
}

/// Avatar yonidagi ixcham badge.
class BusinessBadgeChip extends StatelessWidget {
  final BusinessBadgeInfo info;

  const BusinessBadgeChip({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 4.dp),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.emoji, style: TextStyle(fontSize: 11.sp)),
          SizedBox(width: 4.dp),
          Flexible(
            child: Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.accent,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
