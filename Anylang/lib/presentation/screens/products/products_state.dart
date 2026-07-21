import 'package:get/get.dart';
import 'product.dart';

class ProductsState extends GetxController {
  /// Top mahsulotlar (gorizontal) — Screen.initState'da yuklanadi.
  RxList<Product> top = <Product>[].obs;

  /// Barcha mahsulotlar (grid) — Screen.initState'da yuklanadi.
  RxList<Product> all = <Product>[].obs;

  /// Qidiruv matni.
  RxString query = ''.obs;
}
