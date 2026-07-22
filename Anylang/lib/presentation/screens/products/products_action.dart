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
