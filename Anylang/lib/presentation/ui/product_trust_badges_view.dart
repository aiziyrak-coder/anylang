import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'product_trust_badges.dart';
import 'theme/colors.dart';

/// 🟢 Factory Verified · ISO · Trade Assurance · Premium
class ProductTrustBadgesView extends StatelessWidget {
  final ProductTrustBadges data;
  final bool compact;

  const ProductTrustBadgesView({
    super.key,
    required this.data,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.hasAny) return const SizedBox.shrink();
    final c = context.appColors;
    final items = <({String label, bool on})>[
      (label: 'factory_verified'.tr, on: data.factoryVerified),
      (label: 'factory_badge_iso'.tr, on: data.iso),
      (label: 'product_trust_trade_assurance'.tr, on: data.tradeAssurance),
      (label: 'product_trust_premium'.tr, on: data.premium),
    ].where((e) => e.on).toList();

    return Wrap(
      spacing: compact ? 6.dp : 8.dp,
      runSpacing: compact ? 4.dp : 6.dp,
      children: [
        for (final item in items) _badge(c, item.label),
      ],
    );
  }

  Widget _badge(AppColors c, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.dp : 10.dp,
        vertical: compact ? 4.dp : 6.dp,
      ),
      decoration: BoxDecoration(
        color: c.accentSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 7.dp : 8.dp,
            height: compact ? 7.dp : 8.dp,
            decoration: const BoxDecoration(
              color: kOnline,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 5.dp : 6.dp),
          Text(
            label,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: compact ? 10.sp : 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
