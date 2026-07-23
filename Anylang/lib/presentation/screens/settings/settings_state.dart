import 'package:get/get.dart';
import 'settings_payload.dart';

class SettingsState extends GetxController {
  Rx<SettingsFocus> focus = SettingsFocus.app.obs;
  RxBool newMessagesEnabled = true.obs;
  RxBool friendRequestsEnabled = true.obs;
  RxBool marketingEnabled = false.obs;

  /// Profil ko'rinishi: everyone | friends | nobody
  RxString profileVisibilityKey = 'everyone'.obs;

  RxString currentLanguageKey = 'lang_name_uz'.obs;
}
