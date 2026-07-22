import 'package:get/get.dart';
import '../select_language/select_language_option.dart';

/// Jonli muloqot o'rta body holati.
enum JonliMode {
  idle,
  me,
  other,
}

class JonliState extends GetxController {
  Rx<JonliMode> mode = JonliMode.idle.obs;
  Rx<LanguageOption> myLanguage = languageOptions[0].obs;
  Rx<LanguageOption> otherLanguage = languageOptions[1].obs;

  final RxnInt sessionId = RxnInt();
  final RxString lastOriginal = ''.obs;
  final RxString lastTranslated = ''.obs;
  final RxBool busy = false.obs;
}
