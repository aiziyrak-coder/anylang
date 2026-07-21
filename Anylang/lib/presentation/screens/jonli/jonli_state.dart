import 'package:get/get.dart';
import '../select_language/select_language_option.dart';

/// Jonli muloqot o'rta body holati.
enum JonliMode {
  idle,   // ikkalasi jim — tarjima/playback ko'rinishi (variant c)
  me,     // siz gapiryapsiz (variant d — lime)
  other,  // suhbatdosh gapiryapti (variant b — ko'k)
}

class JonliState extends GetxController {
  /// Joriy holat — bosilgan tugmaga qarab almashadi.
  Rx<JonliMode> mode = JonliMode.idle.obs;

  /// Mening tilim.
  Rx<LanguageOption> myLanguage = languageOptions[0].obs; // O'zbek

  /// Suhbatdosh tili.
  Rx<LanguageOption> otherLanguage = languageOptions[1].obs; // English
}
