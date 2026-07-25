import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/buildNetwork/base_result.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/ai_matching_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/ai_matching_bottom_sheet.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../ui/ai_matching.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../add_product/add_product_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import '../trade_assistant/trade_assistant_screen.dart';
import '../business_feed/business_feed_screen.dart';
import '../business_card_scan/business_card_scan_screen.dart';
import '../marketplace_groups/marketplace_groups_screen.dart';
import '../market_map/market_map_screen.dart';
import '../subscription/subscription_screen.dart';
import 'product.dart';
import 'product_info_bottom_sheet.dart';
import 'products_action.dart';
import 'products_content.dart';
import 'products_state.dart';

const _roleCodes = ['manufacturer', 'distributor', 'retail', 'service'];

class ProductsScreen extends Screen<ProductsState, void> {
  ProductsScreen() : super(mobileContent: ProductsContent());

  Timer? _searchDebounce;
  int _searchSeq = 0;

  @override
  void initState(void payload) {
    state.softRefreshHandler = _onSoftRefresh;
    _loadCategories();
    _load();
    unawaited(_refreshBusinessFlag());
  }

  Future<void> _onSoftRefresh() async {
    await _refreshBusinessFlag();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (identical(state.softRefreshHandler, _onSoftRefresh)) {
      state.softRefreshHandler = null;
    }
    super.dispose();
  }

  String _matchingLocale() {
    final code = _uiLanguage().toLowerCase();
    if (code.startsWith('ru')) return 'ru';
    if (code.startsWith('en') || code.startsWith('us')) return 'en';
    return 'uz';
  }

  Future<void> _loadAiMatchingIfBusiness() async {
    final me = await Get.find<ProfileRepository>().getMe();
    final map = asMap(me.dataOrNull);
    final isBiz = map?['is_business'] == true;
    state.isBusiness.value = isBiz;
    if (!isBiz) {
      state.aiMatching.value = null;
      return;
    }
    state.aiMatchingLoading.value = true;
    final result = await Get.find<AiMatchingRepository>().matches(
      locale: _matchingLocale(),
    );
    state.aiMatchingLoading.value = false;
    result.when(
      success: (data) {
        state.aiMatching.value = AiMatchingResult.fromApi(data);
      },
      failure: (_) {
        state.aiMatching.value = const AiMatchingResult();
      },
    );
  }

  String _uiLanguage() {
    try {
      return SessionStore.appLanguage();
    } catch (_) {
      final code = Get.locale?.toString() ?? 'uz_UZ';
      if (code.startsWith('ru')) return 'ru_RU';
      if (code.startsWith('en') || code.startsWith('us')) return 'us_US';
      return 'uz_UZ';
    }
  }

  List<Product> _mapProducts(dynamic data) {
    return asList(data)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _loadCategories() async {
    final result = await Get.find<ProductsRepository>().categories(
      language: _uiLanguage(),
    );
    result.when(
      success: (data) {
        final items = <ProductCategoryOption>[];
        for (final e in asList(data)) {
          if (e is! Map) continue;
          final code = e['code']?.toString();
          final title = e['title']?.toString();
          if (code == null || code.isEmpty || title == null) continue;
          items.add(ProductCategoryOption(code: code, title: title));
        }
        state.categories.assignAll(items);
      },
      failure: (_) {},
    );
  }

  Map<String, dynamic> _filterParams({String? q, String? sort}) {
    return {
      if (q != null && q.isNotEmpty) 'q': q,
      if (state.category.value != null) 'category': state.category.value,
      if (state.country.value != null) 'country': state.country.value,
      if (state.businessRole.value != null)
        'businessRole': state.businessRole.value,
      'verifiedOnly': state.verifiedOnly.value,
      'readyStock': state.readyStockOnly.value,
      'freeShipping': state.freeShippingOnly.value,
      'premiumSeller': state.premiumSellerOnly.value,
      'newOnly': state.newOnly.value,
      'sort': sort ?? state.listSort,
    };
  }

  Future<BaseResult> _listWithState({
    String? q,
    String? sort,
    int limit = 40,
  }) {
    return Get.find<ProductsRepository>().list(
      q: q,
      category: state.category.value,
      country: state.country.value,
      businessRole: state.businessRole.value,
      verifiedOnly: state.verifiedOnly.value,
      readyStock: state.readyStockOnly.value,
      freeShipping: state.freeShippingOnly.value,
      premiumSeller: state.premiumSellerOnly.value,
      newOnly: state.newOnly.value,
      sort: sort ?? state.listSort,
      limit: limit,
    );
  }

  void _clearQuickFilters() {
    state.category.value = null;
    state.country.value = null;
    state.businessRole.value = null;
    state.verifiedOnly.value = false;
    state.trendOnly.value = false;
    state.readyStockOnly.value = false;
    state.newOnly.value = false;
    state.freeShippingOnly.value = false;
    state.premiumSellerOnly.value = false;
  }

  Future<void> _load({bool keepQuery = false}) async {
    state.loading.value = true;
    state.showingFavorites.value = false;
    if (!keepQuery) {
      state.query.value = '';
      state.smartInterpretation.value = null;
      state.smartSearchActive.value = false;
      state.smartSort.value = null;
    }

    final repo = Get.find<ProductsRepository>();
    final q = keepQuery ? state.query.value.trim() : '';
    final filters = _filterParams(q: q.isEmpty ? null : q);

    final top = await repo.top();
    top.when(
      success: (data) => state.top.assignAll(_mapProducts(data)),
      failure: showAppError,
    );

    if (q.isEmpty && !state.hasActiveFilters) {
      final newest = await repo.list(limit: 12, sort: 'newest');
      newest.when(
        success: (data) => state.newest.assignAll(_mapProducts(data)),
        failure: showAppError,
      );
      final forYou = await repo.forYou(limit: 12);
      forYou.when(
        success: (data) {
          final map = asMap(data);
          state.forYouBasedOnViews.value = map?['based_on_views'] == true;
          state.recommended.assignAll(_mapProducts(data));
        },
        failure: (_) {
          state.forYouBasedOnViews.value = false;
          state.recommended.clear();
        },
      );
    } else {
      state.newest.clear();
      state.recommended.clear();
      state.forYouBasedOnViews.value = false;
    }

    if (q.isNotEmpty) {
      await _runSmartSearch(q);
    } else {
      final all = await _listWithState(
        q: filters['q'] as String?,
        sort: (filters['sort'] as String?) ?? 'newest',
        limit: 40,
      );
      all.when(
        success: (data) => state.all.assignAll(_mapProducts(data)),
        failure: showAppError,
      );
    }
    state.loading.value = false;
  }

  bool _looksLikeSmartQuery(String q) {
    final parts = q.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return true;
    final lower = q.toLowerCase();
    const hints = [
      'turkey',
      'turkiya',
      'factory',
      'textile',
      'manufacturer',
      'toqimachilik',
      "to'qimachilik",
      'ishlab',
      'zavod',
      'rossiya',
      'xitoy',
      'distributor',
      'arzon',
      'cheap',
      'qimmat',
      'expensive',
      'premium',
      'futbolka',
      't-shirt',
      'tshirt',
      'jeans',
      'jinsi',
      'hoodie',
      'kiyim',
      'clothing',
      'дешево',
      'футболка',
    ];
    return hints.any(lower.contains);
  }

  Future<void> _runSmartSearch(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    final seq = ++_searchSeq;
    final locale = _matchingLocale();

    if (!_looksLikeSmartQuery(q)) {
      state.smartSearchActive.value = false;
      state.smartInterpretation.value = null;
      state.smartSort.value = null;
      final result = await Get.find<ProductsRepository>().list(
        q: q,
        category: state.category.value,
        country: state.country.value,
        businessRole: state.businessRole.value,
        verifiedOnly: state.verifiedOnly.value,
      );
      if (seq != _searchSeq) return;
      result.when(
        success: (data) {
          state.all.assignAll(_mapProducts(data));
          state.newest.clear();
          state.recommended.clear();
        },
        failure: showAppError,
      );
      return;
    }

    final result = await Get.find<ProductsRepository>().smartSearch(
      q: q,
      locale: locale,
      limit: 40,
    );
    if (seq != _searchSeq) return;
    result.when(
      success: (data) {
        final map = asMap(data);
        state.smartSearchActive.value = true;
        state.smartInterpretation.value =
            map?['interpretation']?.toString().trim();
        final parsed = asMap(map?['parsed']);
        if (parsed != null) {
          final country = parsed['country']?.toString().trim().toUpperCase();
          state.country.value =
              (country != null && country.length == 2) ? country : null;
          final cat = parsed['category']?.toString().trim();
          state.category.value =
              (cat != null && cat.isNotEmpty) ? cat : null;
          final role = parsed['business_role']?.toString().trim();
          state.businessRole.value =
              (role != null && role.isNotEmpty) ? role : null;
          state.verifiedOnly.value = parsed['verified_only'] == true;
          final sort = parsed['sort']?.toString().trim().toLowerCase();
          if (sort == 'price_asc' || sort == 'price_desc') {
            state.smartSort.value = sort;
          } else {
            state.smartSort.value = null;
          }
        } else {
          state.smartSort.value = null;
        }
        state.all.assignAll(_mapProducts(data));
        state.newest.clear();
        state.recommended.clear();
      },
      failure: (err) async {
        // Fallback: oddiy qidiruv
        state.smartSearchActive.value = false;
        state.smartInterpretation.value = null;
        state.smartSort.value = null;
        final fallback = await Get.find<ProductsRepository>().list(q: q);
        if (seq != _searchSeq) return;
        fallback.when(
          success: (data) {
            state.all.assignAll(_mapProducts(data));
            state.newest.clear();
            state.recommended.clear();
          },
          failure: showAppError,
        );
      },
    );
  }

  Future<void> _reloadWithFilters() async {
    state.searching.value = true;
    final q = state.query.value.trim();
    final sort = state.smartSearchActive.value && q.isNotEmpty
        ? (state.smartSort.value ?? 'recommended')
        : state.listSort;
    final result = await _listWithState(
      q: q.isEmpty || state.smartSearchActive.value ? null : q,
      sort: sort,
      limit: 40,
    );
    result.when(
      success: (data) {
        state.all.assignAll(_mapProducts(data));
        if (q.isNotEmpty || state.hasActiveFilters) {
          state.newest.clear();
          state.recommended.clear();
        }
      },
      failure: showAppError,
    );
    state.searching.value = false;
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerBottomSheet(
      context,
      title: 'products_filter_country'.tr,
      desc: 'products_filter_country_desc'.tr,
      selectedCode: state.country.value,
    );
    if (picked == null) return;
    state.country.value = picked.code.toUpperCase();
    await _reloadWithFilters();
  }

  Future<void> _applyBanner(String id) async {
    _clearQuickFilters();
    state.smartSearchActive.value = false;
    state.smartInterpretation.value = null;
    state.smartSort.value = null;

    switch (id) {
      case 'uz_export':
        state.country.value = 'UZ';
      case 'china_factory':
        state.country.value = 'CN';
        state.businessRole.value = 'manufacturer';
      case 'deals':
        state.trendOnly.value = true;
      case 'ai_recommended':
        state.searching.value = true;
        final result = await Get.find<ProductsRepository>().list(
          sort: 'recommended',
          limit: 40,
        );
        result.when(
          success: (data) {
            state.all.assignAll(_mapProducts(data));
            state.newest.clear();
            state.recommended.clear();
          },
          failure: showAppError,
        );
        state.searching.value = false;
        return;
      default:
        return;
    }
    await _reloadWithFilters();
  }

  Future<void> _pickCategory() async {
    final c = context.appColors;
    final cats = state.categories.toList();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.55,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 28.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'products_quick_product'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.dp),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, ''),
                        borderRadius: BorderRadius.circular(12.dp),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.dp),
                          child: Text(
                            'products_filter_all'.tr,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...cats.map((cat) {
                      final isSelected = state.category.value == cat.code;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, cat.code),
                          borderRadius: BorderRadius.circular(12.dp),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.dp),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cat.title,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: c.accent,
                                    size: 20.dp,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    state.category.value = selected.isEmpty ? null : selected;
    await _reloadWithFilters();
  }

  Future<void> _pickRole() async {
    final c = context.appColors;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 28.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'products_filter_role'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, ''),
                  borderRadius: BorderRadius.circular(12.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.dp),
                    child: Text(
                      'products_role_any'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              ..._roleCodes.map((code) {
                final selected = state.businessRole.value == code;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, code),
                    borderRadius: BorderRadius.circular(12.dp),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.dp),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'business_role_$code'.tr,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_rounded, color: c.accent, size: 20.dp),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    state.businessRole.value = selected.isEmpty ? null : selected;
    await _reloadWithFilters();
  }

  Future<void> _refreshBusinessFlag() async {
    final cached = SessionStore.user()?['is_business'] == true;
    if (cached) state.isBusiness.value = true;
    final me = await Get.find<ProfileRepository>().getMe();
    final map = asMap(me.dataOrNull);
    if (map == null) return;
    await SessionStore.saveUser(Map<String, dynamic>.from(map));
    state.isBusiness.value = map['is_business'] == true;
  }

  Future<void> _openAddProduct() async {
    await _refreshBusinessFlag();
    if (!state.isBusiness.value) {
      final goPlans = await Get.dialog<bool>(
        AlertDialog(
          title: Text('add_product_plan_required_title'.tr),
          content: Text('add_product_plan_required_body'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('common_cancel'.tr),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text('add_product_go_plans'.tr),
            ),
          ],
        ),
      );
      if (goPlans != true) return;
      await navigate(SubscriptionScreen());
      await _refreshBusinessFlag();
      if (!state.isBusiness.value) return;
    }
    await navigate(AddProductScreen());
    await _load(keepQuery: true);
  }

  @override
  Future<void> actionHandler(ProductsState state, MyAction action) async {
    switch (action) {
      case ProductsSearchChanged a:
        state.query.value = a.text;
        _searchDebounce?.cancel();
        if (a.text.trim().isEmpty) {
          state.searching.value = false;
          state.smartInterpretation.value = null;
          state.smartSearchActive.value = false;
          state.smartSort.value = null;
          await _load(keepQuery: false);
          return;
        }
        state.searching.value = true;
        _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
          await _runSmartSearch(a.text.trim());
          state.searching.value = false;
        });
      case RefreshProducts _:
        state.showingFavorites.value = false;
        await _load(keepQuery: true);
        await _refreshBusinessFlag();
      case SoftRefreshProducts _:
        await _refreshBusinessFlag();
      case OpenAddProduct _:
        await _openAddProduct();
      case ShowFavorites _:
        if (state.showingFavorites.value) {
          state.showingFavorites.value = false;
          await _load();
          return;
        }
        state.loading.value = true;
        state.showingFavorites.value = true;
        final fav = await Get.find<ProductsRepository>().listFavorites();
        fav.when(
          success: (data) {
            final items = _mapProducts(data);
            state.top.clear();
            state.newest.clear();
            state.recommended.clear();
            state.all.assignAll(items);
            if (items.isEmpty) showAppMessage('favorites_empty'.tr);
          },
          failure: showAppError,
        );
        state.loading.value = false;
      case OpenTradeAssistant _:
        await navigate(TradeAssistantScreen());
      case OpenBusinessFeed _:
        await navigate(BusinessFeedScreen());
      case OpenMarketplaceGroups _:
        await navigate(MarketplaceGroupsScreen());
      case OpenMarketMap _:
        await navigate<String>(
          MarketMapScreen(),
          onBackResult: (code) async {
            if (code == null || code.isEmpty) return;
            _clearQuickFilters();
            state.smartSearchActive.value = false;
            state.smartInterpretation.value = null;
            state.smartSort.value = null;
            state.country.value = code.toUpperCase();
            state.businessRole.value = 'manufacturer';
            await _reloadWithFilters();
          },
        );
      case OpenBusinessCardScan _:
        await navigate(BusinessCardScanScreen());
      case OpenAiMatching _:
        await _refreshBusinessFlag();
        if (!state.isBusiness.value) {
          showAppError('add_product_business_required'.tr);
          return;
        }
        if (state.aiMatching.value == null && !state.aiMatchingLoading.value) {
          await _loadAiMatchingIfBusiness();
        }
        final data = state.aiMatching.value ?? const AiMatchingResult();
        await showAiMatchingBottomSheet(
          context,
          result: data,
          onOpenCompany: (company) async {
            if (company.id <= 0) return;
            final profile =
                await Get.find<ProfileRepository>().getPublicUser(company.id);
            final map = asMap(profile.dataOrNull);
            if (map == null) {
              showAppError(profile.errorOrNull ?? 'error'.tr);
              return;
            }
            await navigate(
              UserProfileScreen(),
              payload: UserProfilePayload.fromApi(map),
            );
          },
        );
      case RetryAiMatching _:
        await _loadAiMatchingIfBusiness();
      case ProductsSelectCategory a:
        state.category.value = a.code;
        await _reloadWithFilters();
      case ProductsSelectCountry a:
        state.country.value = a.code;
        await _reloadWithFilters();
      case ProductsSelectRole a:
        state.businessRole.value = a.code;
        await _reloadWithFilters();
      case ProductsToggleVerified _:
        state.verifiedOnly.value = !state.verifiedOnly.value;
        await _reloadWithFilters();
      case ProductsToggleFactory _:
        if (state.isFactoryFilter) {
          state.businessRole.value = null;
        } else {
          state.businessRole.value = 'manufacturer';
        }
        await _reloadWithFilters();
      case ProductsToggleTrend _:
        state.trendOnly.value = !state.trendOnly.value;
        await _reloadWithFilters();
      case ProductsToggleReadyStock _:
        state.readyStockOnly.value = !state.readyStockOnly.value;
        await _reloadWithFilters();
      case ProductsToggleNew _:
        state.newOnly.value = !state.newOnly.value;
        await _reloadWithFilters();
      case ProductsToggleFreeShipping _:
        state.freeShippingOnly.value = !state.freeShippingOnly.value;
        await _reloadWithFilters();
      case ProductsTogglePremiumSeller _:
        state.premiumSellerOnly.value = !state.premiumSellerOnly.value;
        await _reloadWithFilters();
      case ProductsClearFilters _:
        _clearQuickFilters();
        state.smartSearchActive.value = false;
        state.smartInterpretation.value = null;
        state.smartSort.value = null;
        state.searching.value = true;
        final q = state.query.value.trim();
        final result = await Get.find<ProductsRepository>().list(
          q: q.isEmpty ? null : q,
          limit: 40,
        );
        result.when(
          success: (data) {
            state.all.assignAll(_mapProducts(data));
            if (q.isNotEmpty) {
              state.newest.clear();
              state.recommended.clear();
            }
          },
          failure: showAppError,
        );
        state.searching.value = false;
      case ProductsPickCountry _:
        await _pickCountry();
      case ProductsPickRole _:
        await _pickRole();
      case ProductsPickCategory _:
        await _pickCategory();
      case ProductsBannerTap a:
        await _applyBanner(a.id);
      case OpenProduct a:
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () async {
            if (a.product.sellerId <= 0) return;
            final result =
                await Get.find<ProfileRepository>().getPublicUser(a.product.sellerId);
            result.when(
              success: (data) {
                final map = asMap(data);
                if (map == null) return;
                navigate(
                  UserProfileScreen(),
                  payload: UserProfilePayload.fromApi(map),
                );
              },
              failure: showAppError,
            );
          },
        );
    }
  }
}
