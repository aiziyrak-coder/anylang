import 'package:get/get.dart';

class SettingsState extends GetxController {
  RxBool newMessagesEnabled = true.obs;
  RxBool friendRequestsEnabled = true.obs;
  RxBool marketingEnabled = false.obs;

  // Joriy ilova tilining kaliti (LanguageOption.key). Boshlang'ich qiymat
  // Screen.initState'da joriy tildan beriladi.
  RxString currentLanguageKey = 'lang_name_uz'.obs;
}
