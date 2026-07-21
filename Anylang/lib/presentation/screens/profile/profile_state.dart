import 'package:get/get.dart';
import 'profile_account.dart';

class ProfileState extends GetxController {
  /// Joriy foydalanuvchi profili — Screen.initState'da yuklanadi.
  Rx<ProfileAccount?> account = Rx<ProfileAccount?>(null);
}
