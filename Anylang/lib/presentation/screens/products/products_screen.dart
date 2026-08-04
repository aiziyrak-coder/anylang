import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/buildNetwork/base_result.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/ai_matching_repository.dart';
import '../../../data/network/payment_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/ai_matching_bottom_sheet.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../modal/payment_confirm_bottom_sheet.dart';
import '../../modal/products_filters_bottom_sheet.dart';
import '../../ui/ai_matching.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/business_plan_dialog.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../add_product/add_product_payload.dart';
import '../add_product/add_product_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import '../trade_assistant/trade_assistant_screen.dart';
import '../business_card_scan/business_card_scan_screen.dart';
import '../marketplace_groups/marketplace_groups_screen.dart';
import '../market_map/market_map_screen.dart';
import '../subscription/subscription_screen.dart';
import 'own_product_actions_sheet.dart';
import 'product.dart';
import 'product_info_bottom_sheet.dart';
import 'products_action.dart';
import 'products_content.dart';
import 'products_state.dart';

const _roleCodes = ['manufacturer', 'distributor', 'retail', 'service'];

class ProductsScreen extends Screen<ProductsState, void> {
  ProductsScreen() : super(mobileContent: ProductsContent());

  int _loadGen = 0;
  Timer? _searchDebounce;
  int _searchSeq = 0;
  int? _pendingPaymentId;
  bool _pendingBoostExtend = false;
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  bool _polling = false;

  @override
  void initState(void payload) {
    state.softRefreshHandler = _onSoftRefresh;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_pendingPaymentId != null) {
          unawaited(_pollPendingBoostPayment(showWaiting: false));
        }
      },
    );
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
    _pollTimer?.cancel();
    _lifecycle?.dispose();
    _pendingPaymentId = null;
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
    state.aiMatchingLoadFailed.value = false;
    final result = await Get.find<AiMatchingRepository>().matches(
      locale: _matchingLocale(),
    );
    state.aiMatchingLoading.value = false;
    result.when(
      success: (data) {
        state.aiMatchingLoadFailed.value = false;
        state.aiMatching.value = AiMatchingResult.fromApi(data);
      },
      failure: (_) {
        state.aiMatchingLoadFailed.value = true;
        state.aiMatching.value = null;
      },
    );
  }

  String _uiLanguage() {
    try {
      return SessionStore.appLanguage();
    } catch (_) {
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
        state.categoriesLoadFailed.value = false;
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
      failure: (_) {
        state.categoriesLoadFailed.value = true;
        showAppWarning('products_categories_failed'.tr);
      },
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
      'freeShipping': false,
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
    state.selectedPromoId.value = null;
  }

  Future<void> _load({bool keepQuery = false}) async {
    final gen = ++_loadGen;
    state.loading.value = true;
    state.showingFavorites.value = false;
    if (!keepQuery) {
      state.query.value = '';
      if (state.searchController.text.isNotEmpty) {
        state.searchController.clear();
      }
      state.smartInterpretation.value = null;
      state.smartSearchActive.value = false;
      state.smartSort.value = null;
    }

    final repo = Get.find<ProductsRepository>();
    final q = keepQuery ? state.query.value.trim() : '';
    final filters = _filterParams(q: q.isEmpty ? null : q);

    final top = await repo.top(limit: 10);
    if (gen != _loadGen) return;
    top.when(
      success: (data) =>
          state.top.assignAll(_mapProducts(data).take(10).toList()),
      failure: showAppError,
    );

    state.newest.clear();

    if (q.isNotEmpty) {
      await _runSmartSearch(q);
      if (gen != _loadGen) return;
    } else {
      final all = await _listWithState(
        q: filters['q'] as String?,
        sort: (filters['sort'] as String?) ?? 'newest',
        limit: 40,
      );
      if (gen != _loadGen) return;
      all.when(
        success: (data) => state.all.assignAll(_mapProducts(data)),
        failure: showAppError,
      );
    }
    if (gen == _loadGen) state.loading.value = false;
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
      final result = await _listWithState(q: q);
      if (seq != _searchSeq) return;
      result.when(
        success: (data) {
          state.all.assignAll(_mapProducts(data));
          state.newest.clear();
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
      },
      failure: (err) async {
        // Fallback: oddiy qidiruv
        state.smartSearchActive.value = false;
        state.smartInterpretation.value = null;
        state.smartSort.value = null;
        final fallback = await _listWithState(q: q);
        if (seq != _searchSeq) return;
        fallback.when(
          success: (data) {
            state.all.assignAll(_mapProducts(data));
            state.newest.clear();
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
      q: q.isEmpty ? null : q,
      sort: sort,
      limit: 40,
    );
    result.when(
      success: (data) {
        state.all.assignAll(_mapProducts(data));
        if (q.isNotEmpty || state.hasActiveFilters) {
          state.newest.clear();
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
    state.selectedPromoId.value = id;

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
          },
          failure: showAppError,
        );
        state.searching.value = false;
        return;
      default:
        state.selectedPromoId.value = null;
        return;
    }
    await _reloadWithFilters();
  }

  /// Filter sheet «Saralash» — draft tanlovlarni bir martada qo‘llash.
  Future<void> _applySheetFilters(ProductsApplySheetFilters a) async {
    final promo = a.promoId?.trim();
    final hasPromo = promo != null && promo.isNotEmpty;

    if (hasPromo && promo == 'ai_recommended') {
      await _applyBanner(promo);
      return;
    }

    _clearQuickFilters();
    state.smartSearchActive.value = false;
    state.smartInterpretation.value = null;
    state.smartSort.value = null;

    if (hasPromo) {
      state.selectedPromoId.value = promo;
      switch (promo) {
        case 'uz_export':
          state.country.value = 'UZ';
        case 'china_factory':
          state.country.value = 'CN';
          state.businessRole.value = 'manufacturer';
        case 'deals':
          state.trendOnly.value = true;
      }
    }

    state.verifiedOnly.value = a.verifiedOnly;
    state.readyStockOnly.value = a.readyStockOnly;
    state.newOnly.value = a.newOnly;
    state.freeShippingOnly.value = a.freeShippingOnly;
    state.premiumSellerOnly.value = a.premiumSellerOnly;

    if (a.factoryOnly || promo == 'china_factory') {
      state.businessRole.value = 'manufacturer';
    }

    if (a.trendOnly || promo == 'deals') {
      state.trendOnly.value = true;
    } else {
      state.trendOnly.value = false;
    }

    final nothingSelected = !hasPromo &&
        !a.verifiedOnly &&
        !a.factoryOnly &&
        !a.trendOnly &&
        !a.readyStockOnly &&
        !a.newOnly &&
        !a.freeShippingOnly &&
        !a.premiumSellerOnly;

    if (nothingSelected) {
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
          }
        },
        failure: showAppError,
      );
      state.searching.value = false;
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
    final me = await Get.find<ProfileRepository>().getMe();
    final map = asMap(me.dataOrNull);
    if (map == null) {
      // Cache bilan optimistik true qoldirmaslik — faqat session.
      state.isBusiness.value = SessionStore.user()?['is_business'] == true;
      return;
    }
    await SessionStore.saveUser(Map<String, dynamic>.from(map));
    state.isBusiness.value = map['is_business'] == true;
  }

  Future<void> _openAddProduct({int? editProductId}) async {
    if (state.addProductBusy.value || isNavigating) return;
    state.addProductBusy.value = true;
    try {
      // FAB faqat isBusiness bo‘lganda ko‘rinadi — tarmoq kutmasdan ochamiz.
      if (!state.isBusiness.value) {
        await _refreshBusinessFlag();
        if (!state.isBusiness.value) {
          final goPlans = await showBusinessPlanRequiredDialog();
          if (!goPlans) return;
          await navigate(SubscriptionScreen());
          await _refreshBusinessFlag();
          if (!state.isBusiness.value) return;
        }
      }
      await navigate(
        AddProductScreen(),
        payload: editProductId != null && editProductId > 0
            ? AddProductPayload(editProductId: editProductId)
            : null,
      );
      await _load(keepQuery: true);
    } finally {
      state.addProductBusy.value = false;
    }
  }

  Future<void> _loadMyProducts() async {
    state.loading.value = true;
    state.showingFavorites.value = false;
    final mine = await Get.find<ProductsRepository>().listMine(limit: 50);
    var ok = false;
    mine.when(
      success: (data) {
        ok = true;
        final items = _mapProducts(data);
        state.top.clear();
        state.newest.clear();
        state.all.assignAll(items);
      },
      failure: showAppError,
    );
    if (!ok) {
      state.all.clear();
    }
    state.loading.value = false;
  }

  Future<void> _handleOwnProduct(Product product) async {
    final action = await showOwnProductActionsSheet(context, product: product);
    if (action == null) return;
    switch (action) {
      case OwnProductAction.edit:
        await _openAddProduct(editProductId: product.id);
      case OwnProductAction.boostTop:
        await _boostProductTop(product);
      case OwnProductAction.publish:
        await _setProductStatus(product, 'published');
      case OwnProductAction.unpublish:
        await _setProductStatus(product, 'draft');
      case OwnProductAction.delete:
        final ok = await Get.dialog<bool>(
              AlertDialog(
                title: Text('my_products_delete_title'.tr),
                content: Text('my_products_delete_body'.tr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text('cancel'.tr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      'my_products_delete'.tr,
                      style: const TextStyle(color: kListenRed),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
        final result =
            await Get.find<ProductsRepository>().archive(product.id);
        if (result.errorOrNull != null) {
          showAppError(result.errorOrNull);
          return;
        }
        showAppMessage('my_products_deleted'.tr);
        await _loadMyProducts();
    }
  }

  Future<void> _setProductStatus(Product product, String status) async {
    final result = await Get.find<ProductsRepository>().update(
      product.id,
      {'status': status},
    );
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      return;
    }
    showAppMessage(
      status == 'published'
          ? 'my_products_published'.tr
          : 'my_products_unpublished'.tr,
    );
    await _loadMyProducts();
  }

  Future<void> _boostProductTop(Product product) async {
    final payments = Get.find<PaymentRepository>();
    final extend = product.isTop || product.topCanExtend;
    final checkout = await payments.checkoutProductTop(
      productId: product.id,
      extend: extend,
    );
    await checkout.when(
      success: (data) async {
        if (data is! Map) return;
        final id = data['id'];
        final checkoutUrl = data['checkout_url']?.toString();
        final mockConfirm = data['mock_confirm'] == true;
        final currency =
            (data['currency']?.toString() ?? 'UZS').toUpperCase();
        final amount = data['amount']?.toString() ?? '';
        final taxPctRaw = data['tax_percent'];
        final taxPct = taxPctRaw is num
            ? taxPctRaw.toInt()
            : int.tryParse('$taxPctRaw') ?? 2;

        final confirmed = await showPaymentConfirmBottomSheet(
          context,
          title: extend
              ? 'my_products_boost_extend'.tr
              : 'my_products_boost_title'.tr,
          subtitle: 'my_products_boost_body'.tr,
          amount: amount,
          currency: currency,
          amountBeforeTax: data['amount_before_tax']?.toString(),
          taxAmount: data['tax_amount']?.toString(),
          taxPercent: taxPct,
          planLabel: product.name,
          periodLabel: 'my_products_boost_period'.trParams({'days': '7'}),
          ctaText: 'my_products_boost_pay'.tr,
        );
        if (confirmed != true) {
          showAppMessage('payment_confirm_later_hint'.tr);
          return;
        }

        if (checkoutUrl != null &&
            checkoutUrl.isNotEmpty &&
            mockConfirm != true) {
          final uri = Uri.tryParse(checkoutUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          if (id is num) {
            _pendingPaymentId = id.toInt();
            _pendingBoostExtend = extend;
            _startBoostPollLoop();
          }
          showAppMessage('my_products_boost_checkout_opened'.tr);
          return;
        }
        if (id is num && (kDebugMode || mockConfirm == true)) {
          final confirmPay = await payments.confirmMock(id.toInt());
          if (confirmPay.errorOrNull != null) {
            showAppError(confirmPay.errorOrNull);
            return;
          }
          showAppMessage(
            extend
                ? 'my_products_boost_extend_success'.tr
                : 'my_products_boost_success'.tr,
          );
          await _loadMyProducts();
        } else {
          showAppMessage('my_products_boost_checkout_opened'.tr);
        }
      },
      failure: (e) async => showAppError(e),
    );
  }

  void _startBoostPollLoop() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_polling) return;
      attempts++;
      final done = await _pollPendingBoostPayment(showWaiting: false);
      if (done || attempts >= 40) {
        _pollTimer?.cancel();
        if (!done && attempts >= 40) {
          _pendingPaymentId = null;
          showAppMessage('subscription_payment_check_hint'.tr);
        }
      }
    });
  }

  Future<bool> _pollPendingBoostPayment({required bool showWaiting}) async {
    final id = _pendingPaymentId;
    if (id == null) {
      if (showWaiting) {
        showAppMessage('subscription_payment_check_hint'.tr);
      }
      return true;
    }
    if (_polling) return false;
    _polling = true;
    try {
      final payments = Get.find<PaymentRepository>();
      final result = await payments.getPayment(id);
      var resolved = false;
      result.when(
        success: (data) {
          final map = asMap(data);
          final status = map?['status']?.toString().toLowerCase();
          if (status == 'paid' ||
              status == 'succeeded' ||
              status == 'completed') {
            resolved = true;
            _pendingPaymentId = null;
            _pollTimer?.cancel();
            showAppMessage(
              _pendingBoostExtend
                  ? 'my_products_boost_extend_success'.tr
                  : 'my_products_boost_success'.tr,
            );
            unawaited(_loadMyProducts());
          } else if (status == 'failed' ||
              status == 'canceled' ||
              status == 'cancelled') {
            resolved = true;
            _pendingPaymentId = null;
            _pollTimer?.cancel();
            showAppMessage('subscription_payment_failed'.tr);
          } else if (showWaiting) {
            showAppMessage('subscription_payment_pending'.tr);
          }
        },
        failure: (e) {
          if (showWaiting) showAppError(e);
        },
      );
      return resolved;
    } finally {
      _polling = false;
    }
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
        if (state.showingFavorites.value) {
          await actionHandler(state, ShowFavorites());
        } else {
          state.showingFavorites.value = false;
          await _load(keepQuery: true);
          await _refreshBusinessFlag();
        }
      case SoftRefreshProducts _:
        await _refreshBusinessFlag();
      case OpenAddProduct _:
        await _openAddProduct();
      case EditOwnProduct a:
        await _openAddProduct(editProductId: a.product.id);
      case BoostOwnProductTop a:
        await _boostProductTop(a.product);
      case ShowFavorites _:
        if (state.showingFavorites.value) {
          state.showingFavorites.value = false;
          await _load();
          return;
        }
        state.loading.value = true;
        state.showingFavorites.value = true;
        final fav = await Get.find<ProductsRepository>().listFavorites();
        var ok = false;
        fav.when(
          success: (data) {
            ok = true;
            final items = _mapProducts(data);
            state.top.clear();
            state.newest.clear();
            state.all.assignAll(items);
          },
          failure: showAppError,
        );
        if (!ok) {
          state.showingFavorites.value = false;
          state.all.clear();
        }
        state.loading.value = false;
      case OpenTradeAssistant _:
        await navigate(TradeAssistantScreen());
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
      case OpenProductsFilters _:
        await showProductsFiltersBottomSheet(
          context,
          state: state,
          sendAction: (a) => actionHandler(state, a),
        );
      case OpenBusinessCardScan _:
        await navigate(BusinessCardScanScreen());
      case OpenAiMatching _:
        await _refreshBusinessFlag();
        if (!state.isBusiness.value) {
          showAppError('add_product_business_required'.tr);
          return;
        }
        if (state.aiMatchingLoadFailed.value) {
          showAppWarning('ai_matching_load_failed'.tr);
          return;
        }
        if (state.aiMatching.value == null && !state.aiMatchingLoading.value) {
          await _loadAiMatchingIfBusiness();
        }
        if (state.aiMatchingLoadFailed.value) {
          showAppWarning('ai_matching_load_failed'.tr);
          return;
        }
        final data = state.aiMatching.value;
        if (data == null || data.items.isEmpty) {
          showAppMessage('ai_matching_empty'.tr);
          return;
        }
        if (!context.mounted) return;
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
            }
          },
          failure: showAppError,
        );
        state.searching.value = false;
      case ProductsApplySheetFilters a:
        await _applySheetFilters(a);
      case ProductsPickCountry _:
        await _pickCountry();
      case ProductsPickRole _:
        await _pickRole();
      case ProductsPickCategory _:
        await _pickCategory();
      case ProductsBannerTap a:
        await _applyBanner(a.id);
      case OpenProduct a:
        final me = SessionStore.userId();
        final isOwner =
            me != null && me > 0 && me == a.product.sellerId;
        await showProductInfoBottomSheet(
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
          onEdit: isOwner
              ? () => unawaited(
                    actionHandler(state, EditOwnProduct(a.product)),
                  )
              : null,
          onManage: isOwner
              ? () => unawaited(_handleOwnProduct(a.product))
              : null,
          onBoostPaid: isOwner
              ? () => unawaited(_loadMyProducts())
              : null,
        );
        if (isOwner) await _load(keepQuery: true);
    }
  }
}
