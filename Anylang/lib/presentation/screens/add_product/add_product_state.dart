import 'package:get/get.dart';
import 'product_image_draft.dart';

class AddProductState extends GetxController {
  RxList<ProductImageDraft> images = <ProductImageDraft>[].obs;
  RxString currency = 'USD'.obs;
  RxString category = ''.obs;
  RxBool isSubmitting = false.obs;
}
