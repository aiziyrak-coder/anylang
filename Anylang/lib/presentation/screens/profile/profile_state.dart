import 'package:get/get.dart';
import 'profile_account.dart';

class ProfileState extends GetxController {
  /// Joriy foydalanuvchi profili — Screen.initState'da yuklanadi.
  Rx<ProfileAccount?> account = Rx<ProfileAccount?>(null);
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
}
