import 'package:get/get.dart';

import '../products/product.dart';
import 'user_profile_payload.dart';

class UserProfileState extends GetxController {
  /// Profil ma'lumoti — Rx, shimmer → to‘liq yuklashda UI yangilanadi.
  final Rxn<UserProfilePayload> dataRx = Rxn<UserProfilePayload>();

  UserProfilePayload? get data => dataRx.value;
  set data(UserProfilePayload? value) => dataRx.value = value;

  final RxBool profileLoading = false.obs;
  /// Boshqa user: cache ko‘rsatilgan, API yangilanmoqda.
  final RxBool profileRefreshing = false.obs;

  final RxList<Product> listings = <Product>[].obs;
  final RxBool listingsLoading = false.obs;

  /// none | pending | accepted
  final RxString friendshipStatus = 'none'.obs;
  final RxnInt friendshipRequestId = RxnInt();
  final RxBool isRequestIncoming = false.obs;
  final RxBool friendBusy = false.obs;
  final RxnString listingsError = RxnString();

  void syncFriendshipFromPayload(UserProfilePayload? p) {
    friendshipStatus.value = p?.friendshipStatus ?? 'none';
    friendshipRequestId.value = p?.friendshipRequestId;
    isRequestIncoming.value = p?.isRequestIncoming ?? false;
  }
}
