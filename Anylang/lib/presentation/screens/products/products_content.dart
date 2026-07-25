import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/ai_matching_card.dart';
import '../../ui/market_analytics_card.dart';
import '../../ui/market_promo_banner.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/items/product_grid_card.dart';
import '../../ui/items/product_top_card.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../modal/product_video_dialog.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'product.dart';
import 'products_action.dart';
import 'products_state.dart';

class ProductsContent extends ScreenContent<ProductsState> {
  // Asosiy ekran body'si ichida ochiladi — fon shaffof, tema gradienti ko'rinadi.
  ProductsContent() : super(color: Colors.transparent);

  @override
  Widget build(
    BuildContext context,
    ProductsState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.dp),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          state.showingFavorites.value
                              ? 'favorites_title'.tr
                              : 'products_title'.tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 27.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Obx(() {
                      if (!state.isBusiness.value ||
                          state.showingFavorites.value) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        onPressed: () => sendAction(OpenAddProduct()),
                        tooltip: 'add_product_title'.tr,
                        icon: Icon(Icons.add_box_rounded, color: c.accent),
                      );
                    }),
                    Obx(
                      () => IconButton(
                        onPressed: () => sendAction(ShowFavorites()),
                        icon: Icon(
                          state.showingFavorites.value
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: c.accent,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => sendAction(OpenBusinessCardScan()),
                      tooltip: 'business_card_scan_title'.tr,
                      icon: Icon(Icons.qr_code_scanner_rounded, color: c.accent),
                    ),
                    IconButton(
                      onPressed: () => sendAction(OpenBusinessFeed()),
                      tooltip: 'feed_title'.tr,
                      icon: Icon(Icons.campaign_outlined, color: c.accent),
                    ),
                    IconButton(
                      onPressed: () => sendAction(OpenMarketplaceGroups()),
                      tooltip: 'marketplace_groups_title'.tr,
                      icon: Icon(Icons.storefront_outlined, color: c.accent),
                    ),
                    IconButton(
                      onPressed: () => sendAction(OpenTradeAssistant()),
                      tooltip: 'trade_ai_title'.tr,
                      icon: Icon(Icons.auto_awesome_rounded, color: c.accent),
                    ),
                  ],
                ),
              ),
          SizedBox(height: 16.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: SearchField(
              hint: 'products_smart_search_hint'.tr,
              onChanged: (v) => sendAction(ProductsSearchChanged(v)),
            ),
          ),
          Obx(() {
            final text = state.smartInterpretation.value;
            if (text == null || text.isEmpty || !state.smartSearchActive.value) {
              return const SizedBox.shrink();
            }
            final colors = context.appColors;
            return Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12.dp),
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.accent,
                      size: 18.dp,
                    ),
                    SizedBox(width: 8.dp),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'products_smart_search_understood'.tr,
                            style: TextStyle(
                              color: colors.accentText,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.dp),
                          Text(
                            text,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Obx(() {
            if (state.showingFavorites.value) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 12.dp),
                MarketPromoBanner(
                  onTap: (id) => sendAction(ProductsBannerTap(id)),
                ),
                SizedBox(height: 12.dp),
                _quickFilters(c, state, sendAction),
              ],
            );
          }),
          Obx(() {
            if (!state.isBusiness.value || state.showingFavorites.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 14.dp, 20.dp, 0),
              child: Column(
                children: [
                  AiMatchingCard(
                    result: state.aiMatching.value,
                    loading: state.aiMatchingLoading.value,
                    onTap: () => sendAction(OpenAiMatching()),
                    onRetry: () => sendAction(RetryAiMatching()),
                  ),
                  SizedBox(height: 10.dp),
                  MarketAnalyticsCard(
                    result: state.marketAnalytics.value,
                    loading: state.marketAnalyticsLoading.value,
                    onTap: () => sendAction(OpenMarketAnalytics()),
                    onRetry: () => sendAction(RetryMarketAnalytics()),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 14.dp),
          Expanded(
            child: Obx(() {
              if (state.loading.value || state.searching.value) {
                return const AppLoading();
              }
              final q = state.query.value.trim();
              final searching = q.isNotEmpty;
              final favorites = state.showingFavorites.value;
              final showSections =
                  !searching && !favorites && !state.hasActiveFilters;
              final all = state.all.toList();

              if (all.isEmpty &&
                  (!showSections ||
                      (state.top.isEmpty &&
                          state.newest.isEmpty &&
                          state.recommended.isEmpty))) {
                return AppEmptyState(
                  icon: searching
                      ? Icons.search_off_rounded
                      : Icons.storefront_outlined,
                  title: searching
                      ? 'empty_no_results'.tr
                      : 'products_empty'.tr,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => sendAction(RefreshProducts()),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSections) ...[
                        if (state.recommended.isNotEmpty) ...[
                          _forYouBlock(context, c, state, sendAction),
                          SizedBox(height: 22.dp),
                        ],
                        if (state.top.isNotEmpty) ...[
                          _sectionHeader(
                            c,
                            icon: Icons.star_rounded,
                            title: 'products_top'.tr,
                          ),
                          SizedBox(height: 12.dp),
                          _horizontalProducts(context, state.top, sendAction),
                          SizedBox(height: 22.dp),
                        ],
                        if (state.newest.isNotEmpty) ...[
                          _sectionHeader(
                            c,
                            icon: Icons.fiber_new_rounded,
                            title: 'products_newest'.tr,
                          ),
                          SizedBox(height: 12.dp),
                          _horizontalProducts(context, state.newest, sendAction),
                          SizedBox(height: 22.dp),
                        ],
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.dp),
                        child: Text(
                          (searching || favorites
                                  ? 'products_results'
                                  : 'products_all')
                              .tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.dp),
                      if (all.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
                          child: Text(
                            'products_empty'.tr,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 16.dp),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.dp,
                            mainAxisSpacing: 12.dp,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: all.length,
                          itemBuilder: (_, i) {
                            final p = all[i];
                            return ProductGridCard(
                              iconAsset: p.iconAsset,
                              tileGradient: p.tileGradient,
                              name: p.name,
                              subtitle: p.subtitle,
                              price: p.price,
                              views: p.views,
                              imageUrl: p.imageUrl,
                              hasVideo: (p.videoUrl ?? '').isNotEmpty,
                              trustBadges: p.trustBadges,
                              capabilities: p.capabilities,
                              onTap: () => sendAction(OpenProduct(p)),
                              onVideoTap: (p.videoUrl ?? '').isEmpty
                                  ? null
                                  : () => showProductVideoDialog(
                                        context,
                                        url: p.videoUrl!,
                                      ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
        ),
        Obx(() {
          if (!state.isBusiness.value || state.showingFavorites.value) {
            return const SizedBox.shrink();
          }
          return Positioned(
            right: 20.dp,
            bottom: 20.dp,
            child: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.lightImpact();
                sendAction(OpenAddProduct());
              },
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'add_product_title'.tr,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _quickFilters(
    AppColors c,
    ProductsState state,
    void Function(MyAction) sendAction,
  ) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.dp),
        child: Row(
          children: [
            _chip(
              c,
              label: 'products_map_view'.tr,
              selected: false,
              onTap: () => sendAction(OpenMarketMap()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_verified'.tr,
              selected: state.verifiedOnly.value,
              onTap: () => sendAction(ProductsToggleVerified()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_factory'.tr,
              selected: state.isFactoryFilter,
              onTap: () => sendAction(ProductsToggleFactory()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_ready_stock'.tr,
              selected: state.readyStockOnly.value,
              onTap: () => sendAction(ProductsToggleReadyStock()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_new'.tr,
              selected: state.newOnly.value,
              onTap: () => sendAction(ProductsToggleNew()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_free_shipping'.tr,
              selected: state.freeShippingOnly.value,
              onTap: () => sendAction(ProductsToggleFreeShipping()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'products_tezkor_premium'.tr,
              selected: state.premiumSellerOnly.value,
              onTap: () => sendAction(ProductsTogglePremiumSeller()),
            ),
            if (state.hasActiveFilters) ...[
              SizedBox(width: 8.dp),
              _chip(
                c,
                label: 'products_filter_clear'.tr,
                selected: false,
                onTap: () => sendAction(ProductsClearFilters()),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _forYouBlock(
    BuildContext context,
    AppColors c,
    ProductsState state,
    void Function(MyAction) sendAction,
  ) {
    final basedOnViews = state.forYouBasedOnViews.value;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.dp),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14.dp, 14.dp, 14.dp, 12.dp),
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(16.dp),
          border: Border.all(color: c.accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('🤖', style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 8.dp),
                Expanded(
                  child: Text(
                    'products_for_you_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.dp),
            Text(
              basedOnViews
                  ? 'products_for_you_subtitle'.tr
                  : 'products_for_you_subtitle_fallback'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            SizedBox(height: 12.dp),
            SizedBox(
              height: 200.dp,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.recommended.length,
                separatorBuilder: (_, _) => SizedBox(width: 12.dp),
                itemBuilder: (_, i) {
                  final p = state.recommended[i];
                  final hasVideo = (p.videoUrl ?? '').isNotEmpty;
                  return ProductTopCard(
                    iconAsset: p.iconAsset,
                    tileGradient: p.tileGradient,
                    name: p.name,
                    price: p.price,
                    views: p.views,
                    imageUrl: p.imageUrl,
                    hasVideo: hasVideo,
                    trustBadges: p.trustBadges,
                    onTap: () => sendAction(OpenProduct(p)),
                    onVideoTap: hasVideo
                        ? () => showProductVideoDialog(context, url: p.videoUrl!)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.dp),
      child: Row(
        children: [
          Icon(icon, color: c.accent, size: 18.dp),
          SizedBox(width: 6.dp),
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalProducts(
    BuildContext context,
    List<Product> items,
    void Function(MyAction) sendAction,
  ) {
    return SizedBox(
      height: 200.dp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.dp),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: 12.dp),
        itemBuilder: (_, i) {
          final p = items[i];
          final hasVideo = (p.videoUrl ?? '').isNotEmpty;
          return ProductTopCard(
            iconAsset: p.iconAsset,
            tileGradient: p.tileGradient,
            name: p.name,
            price: p.price,
            views: p.views,
            imageUrl: p.imageUrl,
            hasVideo: hasVideo,
            trustBadges: p.trustBadges,
            onTap: () => sendAction(OpenProduct(p)),
            onVideoTap: hasVideo
                ? () => showProductVideoDialog(context, url: p.videoUrl!)
                : null,
          );
        },
      ),
    );
  }

  Widget _chip(
    AppColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    VoidCallback? onClear,
  }) {
    return Material(
      color: selected ? c.accent : c.surface,
      borderRadius: BorderRadius.circular(99.dp),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(99.dp),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14.dp,
                  color: selected ? c.onAccent : c.textSecondary,
                ),
                SizedBox(width: 6.dp),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.onAccent : c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onClear != null) ...[
                SizedBox(width: 4.dp),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onClear();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.dp,
                    color: selected ? c.onAccent : c.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
