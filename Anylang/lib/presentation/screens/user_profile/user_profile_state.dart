import 'package:get/get.dart';

import '../products/product.dart';
import 'user_profile_payload.dart';

class UserProfileState extends GetxController {
  /// Profil ma'lumoti (Screen.initState'da payload'dan o'rnatiladi).
  UserProfilePayload? data;

  final RxList<Product> listings = <Product>[].obs;
  final RxBool listingsLoading = false.obs;

  /// none | pending | accepted
  final RxString friendshipStatus = 'none'.obs;
  final RxnInt friendshipRequestId = RxnInt();
  final RxBool isRequestIncoming = false.obs;
  final RxBool friendBusy = false.obs;

  void syncFriendshipFromPayload(UserProfilePayload? p) {
    friendshipStatus.value = p?.friendshipStatus ?? 'none';
    friendshipRequestId.value = p?.friendshipRequestId;
    isRequestIncoming.value = p?.isRequestIncoming ?? false;
  }
}
