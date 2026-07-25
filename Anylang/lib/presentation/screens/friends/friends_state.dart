import 'package:get/get.dart';

import '../products/products_state.dart';
import 'friend.dart';
import 'friend_recommendation.dart';
import 'profile_viewer.dart';

class FriendsState extends GetxController {
  /// Do'stlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Friend> friends = <Friend>[].obs;
  RxString query = ''.obs;
  RxBool loading = true.obs;

  /// Kiruvchi do'st so'rovlari soni (pastki nav badge uchun).
  RxInt pendingCount = 0.obs;

  /// AI Business Match tavsiyalari (yuqori blok).
  RxList<FriendRecommendation> recommendations = <FriendRecommendation>[].obs;
  RxInt recommendationTotalCount = 0.obs;
  RxSet<int> recommendationRequestedIds = <int>{}.obs;

  /// Premium: kim profilingizni ko‘rdi.
  RxList<ProfileViewer> profileViewers = <ProfileViewer>[].obs;
  RxInt profileViewersTotal = 0.obs;
  RxBool profileViewersLocked = false.obs;

  /// Networking Score (profil yonida).
  RxInt networkingConnections = 0.obs;
  RxInt networkingCountries = 0.obs;
  RxnInt networkingTrust = RxnInt();


  /// Qidiruv ostidagi filtrlar.
  RxnString filterCountry = RxnString();
  RxnString filterRole = RxnString();
  RxnString filterProduct = RxnString();
  RxBool filterVerified = false.obs;
  RxBool filterOnline = false.obs;

  /// Mahsulot kategoriyalari (picker uchun).
  RxList<ProductCategoryOption> productCategories = <ProductCategoryOption>[].obs;

  bool get hasActiveFilters =>
      filterCountry.value != null ||
      filterRole.value != null ||
      filterProduct.value != null ||
      filterVerified.value ||
      filterOnline.value;
}
