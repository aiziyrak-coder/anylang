import 'package:get/get.dart';

import 'marketplace_group.dart';

class MarketplaceGroupsState extends GetxController {
  final RxList<MarketplaceGroup> groups = <MarketplaceGroup>[].obs;
  final RxBool loading = true.obs;
  final RxBool joining = false.obs;
  final RxBool viewerVerified = false.obs;
}
