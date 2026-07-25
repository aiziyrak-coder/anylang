import 'package:get/get.dart';
import 'product_image_draft.dart';

class AddProductState extends GetxController {
  RxList<ProductImageDraft> images = <ProductImageDraft>[].obs;
  RxString currency = 'USD'.obs;
  RxString category = ''.obs;
  RxList<String> shippingCountries = <String>[].obs;
  RxList<String> capabilities = <String>[].obs;
  RxBool isSubmitting = false.obs;
  RxnString productVideoUrl = RxnString();
  RxBool videoUploading = false.obs;
}
