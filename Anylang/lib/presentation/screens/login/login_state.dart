import 'package:get/get.dart';

class LoginState extends GetxController {
  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;

  /// Xato / soft-rebuild da inputlar yo‘qolmasin.
  String email = '';
  String password = '';

  /// Multi-account: qo‘shimcha hisob qo‘shish oqimi.
  final RxBool isAddAccount = false.obs;
}
