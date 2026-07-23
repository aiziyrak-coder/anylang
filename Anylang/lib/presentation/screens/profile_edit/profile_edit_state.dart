import 'package:get/get.dart';
import '../profile/profile_account.dart';

class ProfileEditState extends GetxController {
  /// Joriy akkaunt — API hydrate yoki payload.
  final Rxn<ProfileAccount> account = Rxn<ProfileAccount>();

  Rx<DateTime?> birthDate = Rx<DateTime?>(null);
  RxString country = ''.obs;
  RxString gender = 'male'.obs; // 'female' | 'male'
  RxBool isSaving = false.obs;
  final RxInt avatarEpoch = 0.obs;
  /// Forma maydonlarini API bilan sinxronlash.
  final RxInt formEpoch = 0.obs;
}
