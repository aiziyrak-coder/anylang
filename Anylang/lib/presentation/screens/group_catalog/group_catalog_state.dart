import 'package:get/get.dart';

import 'group_catalog_models.dart';

class GroupCatalogState extends GetxController {
  final RxString title = ''.obs;
  final RxInt chatId = 0.obs;
  final RxString section = 'products'.obs;
  final RxBool loading = true.obs;
  final RxList<GroupCatalogProduct> products = <GroupCatalogProduct>[].obs;
  final RxList<GroupCatalogDocument> documents = <GroupCatalogDocument>[].obs;
  final RxList<GroupCatalogCompany> companies = <GroupCatalogCompany>[].obs;
  final RxMap<String, int> counts = <String, int>{}.obs;
}
