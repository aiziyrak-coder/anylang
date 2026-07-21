import 'package:get/get.dart';

class RegisterState extends GetxController {
  RxString gender = 'female'.obs; // 'female' | 'male'
  Rx<DateTime?> birthDate = Rx<DateTime?>(null);
  RxString country = ''.obs; // ko'rsatiladigan nom
  RxString countryCode = ''.obs; // ISO alpha-2
  RxBool termsAccepted = false.obs;
  RxBool isLoading = false.obs;
}
