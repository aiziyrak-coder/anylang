import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/items/product_grid_card.dart';
import '../../ui/items/product_top_card.dart';
import '../../ui/market_promo_banner.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../modal/product_video_dialog.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'product.dart';
import 'products_action.dart';
import 'products_state.dart';

enum _ProductsMenuAction {
  aiMatching,
  scan,
  groups,
  tradeAi,
}

class ProductsContent extends ScreenContent<ProductsState> {
  // Asosiy ekran body'si ichida ochiladi — fon shaffof, tema gradienti ko'rinadi.
  ProductsContent() : super(color: Colors.transparent);

  @override
  Widget build(
    BuildContext context,
    ProductsState state,
    FutureOr<void> Function(MyAction action) sendAction,
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
                padding: EdgeInsets.symmetric(horizontal: 12.dp),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.dp),
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
                    ),
                    Obx(
                      () => IconButton(
                        onPressed: () => sendAction(ShowFavorites()),
                        tooltip: 'favorites_title'.tr,
                        icon: Icon(
                          state.showingFavorites.value
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: c.accent,
                        ),
                      ),
                    ),
                    Obx(() {
                      final active = state.hasActiveFilters;
                      return IconButton(
                        onPressed: () => sendAction(OpenProductsFilters()),
                        tooltip: 'products_filters_title'.tr,
                        icon: Badge(
                          isLabelVisible: active,
                          smallSize: 8.dp,
                          backgroundColor: c.accent,
                          child: Icon(
                            active
                                ? Icons.tune_rounded
                                : Icons.tune_outlined,
                            color: c.accent,
                          ),
                        ),
                      );
                    }),
                    PopupMenuButton<_ProductsMenuAction>(
                      tooltip: 'products_more_menu'.tr,
                      icon: Icon(Icons.more_vert_rounded, color: c.accent),
                      position: PopupMenuPosition.under,
                      onSelected: (action) {
                        HapticFeedback.selectionClick();
                        switch (action) {
                          case _ProductsMenuAction.aiMatching:
                            sendAction(OpenAiMatching());
                          case _ProductsMenuAction.scan:
                            sendAction(OpenBusinessCardScan());
                          case _ProductsMenuAction.groups:
                            sendAction(OpenMarketplaceGroups());
                          case _ProductsMenuAction.tradeAi:
                            sendAction(OpenTradeAssistant());
                        }
                      },
                      itemBuilder: (ctx) {
                        final isBiz = state.isBusiness.value;
                        return [
                          if (isBiz)
                            _menuItem(
                              c,
                              value: _ProductsMenuAction.aiMatching,
                              icon: Icons.hub_outlined,
                              label: 'ai_matching_title'.tr,
                            ),
                          _menuItem(
                            c,
                            value: _ProductsMenuAction.groups,
                            icon: Icons.storefront_outlined,
                            label: 'marketplace_groups_title'.tr,
                          ),
                          _menuItem(
                            c,
                            value: _ProductsMenuAction.tradeAi,
                            icon: Icons.auto_awesome_rounded,
                            label: 'trade_ai_title'.tr,
                          ),
                          _menuItem(
                            c,
                            value: _ProductsMenuAction.scan,
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'business_card_scan_title'.tr,
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.dp),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.dp),
                child: SearchField(
                  hint: 'products_smart_search_hint'.tr,
                  controller: state.searchController,
                  onChanged: (v) => sendAction(ProductsSearchChanged(v)),
                ),
              ),
              Obx(() {
                final text = state.smartInterpretation.value;
                if (text == null ||
                    text.isEmpty ||
                    !state.smartSearchActive.value) {
                  return const SizedBox.shrink();
                }
                final colors = context.appColors;
                return Padding(
                  padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.dp,
                      vertical: 10.dp,
                    ),
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
                if (state.showingFavorites.value ||
                    !state.hasActiveFilters) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.fromLTRB(20.dp, 10.dp, 20.dp, 0),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_rounded,
                          size: 16.dp, color: c.accent),
                      SizedBox(width: 6.dp),
                      Expanded(
                        child: Text(
                          _activeFilterLabel(state),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.accentText,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => sendAction(ProductsClearFilters()),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8.dp),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'products_filter_clear'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 10.dp),
              Expanded(
                child: Obx(() {
                  if (state.loading.value || state.searching.value) {
                    return const AppLoading();
                  }
                  final q = state.query.value.trim();
                  final searching = q.isNotEmpty;
                  final favorites = state.showingFavorites.value;
                  final showSections =
                      !searching &&
                      !favorites &&
                      !state.hasActiveFilters;
                  final all = state.all.toList();

                  if (all.isEmpty &&
                      (!showSections ||
                          (state.top.isEmpty && state.newest.isEmpty))) {
                    return AppEmptyState(
                      icon: searching
                          ? Icons.search_off_rounded
                          : favorites
                              ? Icons.favorite_border_rounded
                              : Icons.storefront_outlined,
                      title: searching
                          ? 'empty_no_results'.tr
                          : favorites
                              ? 'favorites_empty'.tr
                              : 'products_empty'.tr,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async { await sendAction(RefreshProducts()); },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 88.dp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showSections) ...[
                            if (state.top.isNotEmpty) ...[
                              _sectionHeader(
                                c,
                                icon: Icons.star_rounded,
                                title: 'products_top'.tr,
                              ),
                              SizedBox(height: 12.dp),
                              _horizontalProducts(
                                context,
                                state.top,
                                sendAction,
                              ),
                              SizedBox(height: 22.dp),
                            ],
                            if (state.newest.isNotEmpty) ...[
                              _sectionHeader(
                                c,
                                icon: Icons.fiber_new_rounded,
                                title: 'products_newest'.tr,
                              ),
                              SizedBox(height: 12.dp),
                              _horizontalProducts(
                                context,
                                state.newest,
                                sendAction,
                              ),
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
                              padding: EdgeInsets.fromLTRB(
                                20.dp,
                                8.dp,
                                20.dp,
                                24.dp,
                              ),
                              child: AppEmptyState(
                                icon: favorites
                                    ? Icons.favorite_border_rounded
                                    : Icons.storefront_outlined,
                                title: favorites
                                    ? 'favorites_empty'.tr
                                    : 'products_empty'.tr,
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                16.dp,
                                0,
                                16.dp,
                                16.dp,
                              ),
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
          if (state.showingFavorites.value || !state.isBusiness.value) {
            return const SizedBox.shrink();
          }
          final busy = state.addProductBusy.value;
          return Positioned(
            right: 20.dp,
            bottom: 20.dp,
            child: FloatingActionButton.extended(
              onPressed: busy
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      sendAction(OpenAddProduct());
                    },
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              icon: busy
                  ? SizedBox(
                      width: 18.dp,
                      height: 18.dp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.onAccent,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                'common_add'.tr,
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

  PopupMenuItem<_ProductsMenuAction> _menuItem(
    AppColors c, {
    required _ProductsMenuAction value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<_ProductsMenuAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: c.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _activeFilterLabel(ProductsState state) {
    final promo = state.selectedPromoId.value;
    if (promo != null && promo.isNotEmpty) {
      for (final slide in MarketPromoBanner.slides) {
        if (slide.id == promo) return slide.titleKey.tr;
      }
    }
    final parts = <String>[];
    if (state.verifiedOnly.value) parts.add('products_tezkor_verified'.tr);
    if (state.isFactoryFilter) parts.add('products_tezkor_factory'.tr);
    if (state.trendOnly.value) parts.add('products_tezkor_trend'.tr);
    if (state.readyStockOnly.value) {
      parts.add('products_tezkor_ready_stock'.tr);
    }
    if (state.newOnly.value) parts.add('products_tezkor_new'.tr);
    if (state.freeShippingOnly.value) {
      parts.add('products_tezkor_free_shipping'.tr);
    }
    if (state.premiumSellerOnly.value) {
      parts.add('products_tezkor_premium'.tr);
    }
    if (state.country.value != null) {
      parts.add(state.country.value!);
    }
    if (parts.isEmpty) return 'products_filters_title'.tr;
    return parts.join(' · ');
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
}
