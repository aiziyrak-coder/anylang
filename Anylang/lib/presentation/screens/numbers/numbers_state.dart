import 'package:get/get.dart';

import 'number_models.dart';

class NumbersState extends GetxController {
  final loading = true.obs;
  final catalogLoading = false.obs;
  final purchasing = false.obs;
  final error = RxnString();
  final my = Rxn<MyNumberInfo>();
  final groups = <NumberGroupInfo>[].obs;
  final items = <CatalogNumber>[].obs;
  final selectedGroupId = RxnInt();
  final searchQuery = ''.obs;
  final sort = 'price_asc'.obs;
  final hasBonusOnly = false.obs;
  final page = 1.obs;
  final hasMore = false.obs;
  final total = 0.obs;
  final awaitingPayment = false.obs;
}
