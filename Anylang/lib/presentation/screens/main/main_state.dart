import 'package:get/get.dart';

class MainState extends GetxController {
  /// Joriy tanlangan tab indeksi (0 = Xabarlar).
  RxInt currentTab = 0.obs;

  /// Chiqish uchun ikki marta orqaga — oxirgi ogohlantirish vaqti.
  DateTime? lastExitPromptAt;
}
