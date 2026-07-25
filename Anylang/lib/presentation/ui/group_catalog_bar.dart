import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Guruh chatida Group Catalog bo‘limlari — Products / Documents / Companies.
class GroupCatalogBar extends StatelessWidget {
  final ValueChanged<String> onOpenSection;

  const GroupCatalogBar({super.key, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 8.dp),
      child: Row(
        children: [
          Expanded(
            child: _chip(
              c,
              emoji: '📦',
              label: 'group_catalog_products'.tr,
              section: 'products',
            ),
          ),
          SizedBox(width: 8.dp),
          Expanded(
            child: _chip(
              c,
              emoji: '📄',
              label: 'group_catalog_documents'.tr,
              section: 'documents',
            ),
          ),
          SizedBox(width: 8.dp),
          Expanded(
            child: _chip(
              c,
              emoji: '🏭',
              label: 'group_catalog_companies'.tr,
              section: 'companies',
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    AppColors c, {
    required String emoji,
    required String label,
    required String section,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenSection(section),
        borderRadius: BorderRadius.circular(12.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 8.dp, horizontal: 6.dp),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12.dp),
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: 16.sp)),
              SizedBox(height: 2.dp),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
