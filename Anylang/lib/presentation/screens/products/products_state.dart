import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../ui/ai_matching.dart';
import 'product.dart';

class ProductCategoryOption {
  final String code;
  final String title;

  const ProductCategoryOption({required this.code, required this.title});
}

class ProductsState extends GetxController {
  RxList<Product> top = <Product>[].obs;
  RxList<Product> newest = <Product>[].obs;
  RxList<Product> recommended = <Product>[].obs;
  /// for-you: ko‘rilganlarga asoslanganmi.
  RxBool forYouBasedOnViews = false.obs;
  RxList<Product> all = <Product>[].obs;
  RxList<ProductCategoryOption> categories = <ProductCategoryOption>[].obs;

  RxString query = ''.obs;
  RxnString category = RxnString();
  RxnString country = RxnString();
  RxnString businessRole = RxnString();
  RxBool verifiedOnly = false.obs;
  /// 🔥 Trend — TOP / ko‘p ko‘rilganlar (banner).
  RxBool trendOnly = false.obs;
  RxBool readyStockOnly = false.obs;
  RxBool newOnly = false.obs;
  RxBool freeShippingOnly = false.obs;
  RxBool premiumSellerOnly = false.obs;

  RxBool loading = true.obs;
  RxBool searching = false.obs;
  RxBool showingFavorites = false.obs;

  RxBool isBusiness = false.obs;
  final Rxn<AiMatchingResult> aiMatching = Rxn<AiMatchingResult>();
  final RxBool aiMatchingLoading = false.obs;

  /// Search field sync (clear/load bilan UI bir xil bo‘lsin).
  final TextEditingController searchController = TextEditingController();

  /// Smart Search AI tushuntirishi (masalan: Turkiyadagi to‘qimachilik…).
  final RxnString smartInterpretation = RxnString();
  final RxBool smartSearchActive = false.obs;
  /// Smart Search dan kelgan sort (`price_asc` / `price_desc`).
  final RxnString smartSort = RxnString();

  /// Main tab soft-refresh (IndexedStack).
  Future<void> Function()? softRefreshHandler;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  bool get hasActiveFilters =>
      category.value != null ||
      country.value != null ||
      businessRole.value != null ||
      verifiedOnly.value ||
      trendOnly.value ||
      readyStockOnly.value ||
      newOnly.value ||
      freeShippingOnly.value ||
      premiumSellerOnly.value;

  bool get isFactoryFilter => businessRole.value == 'manufacturer';

  String get listSort {
    if (trendOnly.value) return 'top';
    if (newOnly.value) return 'newest';
    return 'newest';
  }
}
