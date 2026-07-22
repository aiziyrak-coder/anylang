import 'package:get/get.dart';
import '../profile/profile_account.dart';

class ProfileEditState extends GetxController {
  /// `ProfileScreen`dan payload sifatida kelgan joriy akkaunt (avatar/ism uchun).
  ProfileAccount? account;

  Rx<DateTime?> birthDate = Rx<DateTime?>(null);
  RxString country = ''.obs;
  RxString gender = 'female'.obs; // 'female' | 'male'
  RxBool isSaving = false.obs;
  final RxInt avatarEpoch = 0.obs;
}
