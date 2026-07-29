import 'package:get/get.dart';

import 'marketplace_verified_group_models.dart';

class MarketplaceVerifiedGroupState extends GetxController {
  final RxString slug = ''.obs;
  final RxString emoji = '🏪'.obs;
  final RxString title = ''.obs;
  final RxString blurb = ''.obs;
  final RxInt memberCount = 0.obs;
  final RxInt rfqToday = 0.obs;
  final RxBool loading = true.obs;
  final RxBool joining = false.obs;
  final Rxn<MarketplaceVerifiedGroupPreview> preview =
      Rxn<MarketplaceVerifiedGroupPreview>();
  final RxnString loadError = RxnString();
}
