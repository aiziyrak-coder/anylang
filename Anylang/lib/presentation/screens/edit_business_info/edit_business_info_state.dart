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
  RxString seoText = ''.obs;
  RxList<String> keywords = <String>[].obs;
  final RxMap<String, String> descriptionI18n = <String, String>{}.obs;
  RxString aiPrompt = ''.obs;
  RxBool aiGenerating = false.obs;
  RxBool showTranslations = false.obs;
  RxnInt foundedYear = RxnInt();
  RxString moq = ''.obs;
  RxString productionCapacity = ''.obs;
  RxString leadTime = ''.obs;
  RxList<String> certificates = <String>[].obs;
  RxList<String> exportCountries = <String>[].obs;
  RxList<String> incoterms = <String>[].obs;
  RxList<String> paymentMethods = <String>[].obs;
  RxList<FactoryImageItem> factoryImages = <FactoryImageItem>[].obs;
  RxBool factoryVerified = false.obs;
  RxBool inspectionPassed = false.obs;
  final RxnString auditReportUrl = RxnString();
  RxBool isSaving = false.obs;
  RxBool loading = true.obs;
  final RxnString logoUrl = RxnString();
  /// Controllersni UI yangilash uchun — API hydrate bo'lganda ++.
  final RxInt formEpoch = 0.obs;
}
