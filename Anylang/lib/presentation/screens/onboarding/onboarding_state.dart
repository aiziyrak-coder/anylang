import 'package:get/get.dart';

class OnboardingState extends GetxController {
  // Joriy sahifa indeksi (0..3) — oxirgi: ruxsatlar.
  RxInt currentPage = 0.obs;
  RxBool requestingPermissions = false.obs;
}
