import '../../utils/screen_options/my_action.dart';
import 'product.dart';

/// Faqat Bozor (Mahsulotlar) ekraniga xos action'lar.
class ProductsAction extends MyAction {}

/// Qidiruv matni o'zgarganda.
class ProductsSearchChanged extends ProductsAction {
  final String text;
  ProductsSearchChanged(this.text);
}

/// Mahsulot bosilganda — info bottom sheet ochiladi.
class OpenProduct extends ProductsAction {
  final Product product;
  OpenProduct(this.product);
}

/// Ro'yxatni qayta yuklash (pull-to-refresh).
class RefreshProducts extends ProductsAction {}

/// Sevimlilar ro'yxatini ko'rsatish.
class ShowFavorites extends ProductsAction {}

/// AI savdo yordamchisi (marketplace).
class OpenTradeAssistant extends ProductsAction {}

class OpenAiMatching extends ProductsAction {}

class RetryAiMatching extends ProductsAction {}

class OpenMarketplaceGroups extends ProductsAction {}

/// 🌍 Map View — ishlab chiqaruvchilar xaritasi.
class OpenMarketMap extends ProductsAction {}

/// Ko‘rgazma: Business Card QR skaner.
class OpenBusinessCardScan extends ProductsAction {}

/// Kategoriya filtri.
class ProductsSelectCategory extends ProductsAction {
  final String? code;
  ProductsSelectCategory(this.code);
}

/// Davlat filtri (null = barcha).
class ProductsSelectCountry extends ProductsAction {
  final String? code;
  ProductsSelectCountry(this.code);
}

/// Yetkazib beruvchi turi.
class ProductsSelectRole extends ProductsAction {
  final String? code;
  ProductsSelectRole(this.code);
}

/// Faqat verified kompaniyalar.
class ProductsToggleVerified extends ProductsAction {}

/// 🏭 Factory — manufacturer filtri (bir bosish).
class ProductsToggleFactory extends ProductsAction {}

/// 🔥 Trend — TOP sort.
class ProductsToggleTrend extends ProductsAction {}

/// Ready Stock.
class ProductsToggleReadyStock extends ProductsAction {}

/// New (so‘nggi 30 kun).
class ProductsToggleNew extends ProductsAction {}

/// Free Shipping.
class ProductsToggleFreeShipping extends ProductsAction {}

/// Premium Seller.
class ProductsTogglePremiumSeller extends ProductsAction {}

/// Barcha filtrlarni tozalash.
class ProductsClearFilters extends ProductsAction {}

/// Filter sheet — «Saralash» (draft → apply + dismiss).
class ProductsApplySheetFilters extends ProductsAction {
  final String? promoId;
  final bool verifiedOnly;
  final bool factoryOnly;
  final bool trendOnly;
  final bool readyStockOnly;
  final bool newOnly;
  final bool freeShippingOnly;
  final bool premiumSellerOnly;

  ProductsApplySheetFilters({
    this.promoId,
    required this.verifiedOnly,
    required this.factoryOnly,
    required this.trendOnly,
    required this.readyStockOnly,
    required this.newOnly,
    required this.freeShippingOnly,
    required this.premiumSellerOnly,
  });
}

/// Filter bottom sheet (promo kolleksiyalar + tezkor filterlar).
class OpenProductsFilters extends ProductsAction {}

/// Davlat tanlash sheet'ini ochish.
class ProductsPickCountry extends ProductsAction {}

/// Rol tanlash sheet'ini ochish.
class ProductsPickRole extends ProductsAction {}

/// Mahsulot kategoriyasi tanlash sheet'ini ochish.
class ProductsPickCategory extends ProductsAction {}

/// Promo banner bosilganda.
class ProductsBannerTap extends ProductsAction {
  final String id;
  ProductsBannerTap(this.id);
}

/// Biznes — mahsulot qo‘shish (FAB / header).
class OpenAddProduct extends ProductsAction {}

/// Egasi: tahrirlash.
class EditOwnProduct extends ProductsAction {
  final Product product;
  EditOwnProduct(this.product);
}

/// Egasi: o‘chirish (arxiv).
class DeleteOwnProduct extends ProductsAction {
  final Product product;
  DeleteOwnProduct(this.product);
}

/// Egasi: e'lon / qoralama.
class ToggleOwnProductPublish extends ProductsAction {
  final Product product;
  ToggleOwnProductPublish(this.product);
}

/// Egasi: TOP boost ($5/oy).
class BoostOwnProductTop extends ProductsAction {
  final Product product;
  BoostOwnProductTop(this.product);
}

/// Tab qayta ochilganda is_business / AI kartalarni soft yangilash.
class SoftRefreshProducts extends ProductsAction {}
