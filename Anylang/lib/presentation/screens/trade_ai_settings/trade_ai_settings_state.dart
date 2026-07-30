import 'package:get/get.dart';

class TradeAiSettingsState extends GetxController {
  RxBool loading = true.obs;
  RxBool saving = false.obs;
  RxnString loadError = RxnString();
  RxString knowledge = ''.obs;
  RxString companyName = ''.obs;
}
