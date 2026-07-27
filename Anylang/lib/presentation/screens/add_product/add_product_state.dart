import 'package:get/get.dart';
import 'product_image_draft.dart';

class AddProductState extends GetxController {
  RxList<ProductImageDraft> images = <ProductImageDraft>[].obs;
  RxString currency = 'USD'.obs;
  RxString category = ''.obs;
  RxList<String> shippingCountries = <String>[].obs;
  RxBool isSubmitting = false.obs;
  RxnString productVideoUrl = RxnString();
  RxBool videoUploading = false.obs;

  /// null = yangi mahsulot; >0 = tahrirlash.
  final RxnInt editingProductId = RxnInt();

  /// Edit hydrate (content TextFieldlarga bir marta yozadi).
  final RxnString draftName = RxnString();
  final RxnString draftPrice = RxnString();
  final RxnString draftShort = RxnString();
  final RxnString draftDetailed = RxnString();
  final RxnString draftMoq = RxnString();
  final RxnString draftShipping = RxnString();
  final RxnString draftFactoryVideo = RxnString();
  final RxnString draftProcessVideo = RxnString();
  final RxInt draftHydrateToken = 0.obs;

  bool get isEditing => (editingProductId.value ?? 0) > 0;
}
