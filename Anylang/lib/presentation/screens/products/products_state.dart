import 'package:get/get.dart';
import 'product.dart';

class ProductsState extends GetxController {
  RxList<Product> top = <Product>[].obs;
  RxList<Product> all = <Product>[].obs;
  RxString query = ''.obs;
  RxBool loading = true.obs;
  RxBool searching = false.obs;
}
