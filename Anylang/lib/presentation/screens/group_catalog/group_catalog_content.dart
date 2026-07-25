import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/group_catalog_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'group_catalog_action.dart';
import 'group_catalog_state.dart';

class GroupCatalogContent extends ScreenContent<GroupCatalogState> {
  @override
  Widget build(
    BuildContext context,
    GroupCatalogState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 8.dp, 0),
              child: AppTopBar(
                title: 'group_catalog_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Obx(() {
              final subtitle = state.title.value.trim();
              if (subtitle.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.fromLTRB(20.dp, 4.dp, 20.dp, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                  ),
                ),
              );
            }),
            SizedBox(height: 12.dp),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.dp),
              child: Obx(() {
                final section = state.section.value;
                return Row(
                  children: [
                    Expanded(
                      child: _SectionChip(
                        emoji: '📦',
                        label: 'group_catalog_products'.tr,
                        selected: section == 'products',
                        onTap: () =>
                            sendAction(GroupCatalogSelectSection('products')),
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    Expanded(
                      child: _SectionChip(
                        emoji: '📄',
                        label: 'group_catalog_documents'.tr,
                        selected: section == 'documents',
                        onTap: () =>
                            sendAction(GroupCatalogSelectSection('documents')),
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    Expanded(
                      child: _SectionChip(
                        emoji: '🏭',
                        label: 'group_catalog_companies'.tr,
                        selected: section == 'companies',
                        onTap: () =>
                            sendAction(GroupCatalogSelectSection('companies')),
                      ),
                    ),
                  ],
                );
              }),
            ),
            SizedBox(height: 8.dp),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const Center(child: AppLoading());
                }
                final section = state.section.value;
                if (section == 'products') {
                  if (state.products.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'group_catalog_products_empty'.tr,
                      subtitle: 'group_catalog_products_empty_hint'.tr,
                    );
                  }
                  return RefreshIndicator(
                    color: c.accent,
                    onRefresh: () async => sendAction(GroupCatalogRefresh()),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                      itemCount: state.products.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.dp),
                      itemBuilder: (context, i) {
                        final item = state.products[i];
                        return GroupCatalogProductItem(
                          item: item,
                          onTap: () =>
                              sendAction(GroupCatalogOpenProduct(item)),
                        );
                      },
                    ),
                  );
                }
                if (section == 'documents') {
                  if (state.documents.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.description_outlined,
                      title: 'group_catalog_documents_empty'.tr,
                      subtitle: 'group_catalog_documents_empty_hint'.tr,
                    );
                  }
                  return RefreshIndicator(
                    color: c.accent,
                    onRefresh: () async => sendAction(GroupCatalogRefresh()),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                      itemCount: state.documents.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.dp),
                      itemBuilder: (context, i) {
                        final item = state.documents[i];
                        return GroupCatalogDocumentItem(
                          item: item,
                          onTap: () =>
                              sendAction(GroupCatalogOpenDocument(item)),
                        );
                      },
                    ),
                  );
                }
                if (state.companies.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.factory_outlined,
                    title: 'group_catalog_companies_empty'.tr,
                    subtitle: 'group_catalog_companies_empty_hint'.tr,
                  );
                }
                return RefreshIndicator(
                  color: c.accent,
                  onRefresh: () async => sendAction(GroupCatalogRefresh()),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                    itemCount: state.companies.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.dp),
                    itemBuilder: (context, i) {
                      final item = state.companies[i];
                      return GroupCatalogCompanyItem(
                        item: item,
                        onTap: () =>
                            sendAction(GroupCatalogOpenCompany(item)),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 10.dp, horizontal: 6.dp),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: selected ? c.accent : c.surfaceBorder),
          ),
          child: Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              SizedBox(height: 4.dp),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? c.accent : c.textSecondary,
                  fontSize: 11.sp,
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
