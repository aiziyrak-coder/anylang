import 'package:get/get.dart';

class SelectLanguageState extends GetxController {
  // Tanlangan tilning noyob kaliti (LanguageOption.key).
  // Boshlang'ich qiymat Screen.initState'da joriy tildan beriladi.
  RxString selectedKey = 'lang_name_uz'.obs;

  // Qidiruv matni.
  RxString query = ''.obs;
}
