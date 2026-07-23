import 'package:get/get.dart';

class FactoryImageItem {
  final int id;
  final String url;
  const FactoryImageItem({required this.id, required this.url});
}

class EditBusinessInfoState extends GetxController {
  RxString companyName = ''.obs;
  RxString country = ''.obs;
  RxString role = ''.obs;
  RxString website = ''.obs;
  RxString description = ''.obs;
  RxList<String> certificates = <String>[].obs;
  RxList<FactoryImageItem> factoryImages = <FactoryImageItem>[].obs;
  RxBool isSaving = false.obs;
  RxBool loading = true.obs;
  final RxnString logoUrl = RxnString();
  /// Controllersni UI yangilash uchun — API hydrate bo'lganda ++.
  final RxInt formEpoch = 0.obs;
}
