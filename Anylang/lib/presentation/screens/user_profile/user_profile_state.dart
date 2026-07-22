import 'package:get/get.dart';

import '../products/product.dart';
import 'user_profile_payload.dart';

class UserProfileState extends GetxController {
  /// Profil ma'lumoti (Screen.initState'da payload'dan o'rnatiladi).
  UserProfilePayload? data;

  final RxList<Product> listings = <Product>[].obs;
  final RxBool listingsLoading = false.obs;
}
