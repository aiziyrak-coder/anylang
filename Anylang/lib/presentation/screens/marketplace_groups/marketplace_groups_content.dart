import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/marketplace_group_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'marketplace_group.dart';
import 'marketplace_groups_action.dart';
import 'marketplace_groups_state.dart';

class MarketplaceGroupsContent extends ScreenContent<MarketplaceGroupsState> {
  @override
  Widget build(
    BuildContext context,
    MarketplaceGroupsState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 8.dp, 0),
              child: AppTopBar(
                title: 'marketplace_groups_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 0),
              child: Text(
                'marketplace_groups_hint'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
              ),
            ),
            SizedBox(height: 8.dp),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const Center(child: AppLoading());
                }
                final err = state.loadError.value;
                final open = state.groups.where((g) => !g.verifiedOnly).toList();
                final verified = state.groups.where((g) => g.verifiedOnly).toList();
                if (err != null && open.isEmpty && verified.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'marketplace_groups_load_failed'.tr,
                    subtitle: err,
                    actionLabel: 'common_retry'.tr,
                    onAction: () => sendAction(MarketplaceGroupsRefresh()),
                  );
                }
                if (open.isEmpty && verified.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'marketplace_groups_empty'.tr,
                    subtitle: 'marketplace_groups_hint'.tr,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async { await sendAction(MarketplaceGroupsRefresh()); },
                  color: c.accent,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                    children: [
                      if (open.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'marketplace_section_open'.tr,
                          color: c.textPrimary,
                        ),
                        SizedBox(height: 10.dp),
                        ..._groupTiles(open, sendAction),
                      ],
                      if (verified.isNotEmpty) ...[
                        if (open.isNotEmpty) SizedBox(height: 20.dp),
                        _SectionHeader(
                          title: 'marketplace_section_verified'.tr,
                          color: c.accent,
                        ),
                        SizedBox(height: 6.dp),
                        Text(
                          'marketplace_verified_hint'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                        if (!state.viewerVerified.value) ...[
                          SizedBox(height: 8.dp),
                          Text(
                            'marketplace_verified_need_badge'.tr,
                            style: TextStyle(
                              color: c.textFaint,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        SizedBox(height: 10.dp),
                        ..._groupTiles(verified, sendAction),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupTiles(
    List<MarketplaceGroup> groups,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final out = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) out.add(SizedBox(height: 12.dp));
      final g = groups[i];
      out.add(
        MarketplaceGroupItem(
          group: g,
          onTap: () => sendAction(MarketplaceGroupOpen(g)),
        ),
      );
    }
    return out;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 14.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}
