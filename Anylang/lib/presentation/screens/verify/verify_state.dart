import 'package:get/get.dart';

class VerifyState extends GetxController {
  RxString email = ''.obs;
  RxString code = ''.obs;
  RxInt secondsLeft = 0.obs; // qayta yuborishgacha qolgan vaqt
  RxBool isLoading = false.obs;
}
