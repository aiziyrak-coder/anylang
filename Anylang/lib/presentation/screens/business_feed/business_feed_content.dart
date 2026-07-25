import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/business_feed_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'business_feed_action.dart';
import 'business_feed_state.dart';
import 'feed_post.dart';

/// Business Feed — faqat biznes yangiliklari (mahsulot, zavod, sertifikat, ko‘rgazma, chegirma).
class BusinessFeedContent extends ScreenContent<BusinessFeedState> {
  @override
  Widget build(
    BuildContext context,
    BusinessFeedState state,
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
                title: 'feed_title'.tr,
                onBack: () => sendAction(Back()),
                trailing: Obx(() {
                  if (!state.isBusiness.value) return const SizedBox.shrink();
                  return IconButton(
                    onPressed: () => sendAction(FeedCreateRequested()),
                    icon: Icon(Icons.add_rounded, color: c.textPrimary),
                    tooltip: 'feed_create_title'.tr,
                  );
                }),
              ),
            ),
            SizedBox(height: 8.dp),
            SizedBox(
              height: 40.dp,
              child: Obx(() {
                final selected = state.filterType.value;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.dp),
                  children: [
                    _FilterChip(
                      label: 'feed_filter_all'.tr,
                      selected: selected == null,
                      onTap: () => sendAction(FeedSelectType(null)),
                    ),
                    for (final t in kFeedPostTypes) ...[
                      SizedBox(width: 8.dp),
                      _FilterChip(
                        label: feedTypeLabelKey(t).tr,
                        selected: selected == t,
                        onTap: () => sendAction(FeedSelectType(t)),
                      ),
                    ],
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
                if (state.posts.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'feed_empty_title'.tr,
                    subtitle: 'feed_empty_desc'.tr,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => sendAction(FeedRefreshRequested()),
                  color: c.accent,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                        sendAction(FeedLoadMoreRequested());
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                      itemCount: state.posts.length + (state.loadingMore.value ? 1 : 0),
                      separatorBuilder: (_, __) => SizedBox(height: 12.dp),
                      itemBuilder: (context, i) {
                        if (i >= state.posts.length) {
                          return Padding(
                            padding: EdgeInsets.all(16.dp),
                            child: const Center(child: AppLoading()),
                          );
                        }
                        final post = state.posts[i];
                        return BusinessFeedItem(
                          post: post,
                          onAuthorTap: () =>
                              sendAction(FeedOpenAuthor(post.author.id)),
                          onDelete: post.isMine
                              ? () => sendAction(FeedDeleteRequested(post.id))
                              : null,
                        );
                      },
                    ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        borderRadius: BorderRadius.circular(99.dp),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(color: selected ? c.accent : c.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.onAccent : c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
