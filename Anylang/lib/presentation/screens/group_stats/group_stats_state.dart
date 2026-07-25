import 'package:get/get.dart';

import 'group_stats_models.dart';

class GroupStatsState extends GetxController {
  final RxString title = ''.obs;
  final RxInt chatId = 0.obs;
  final RxBool loading = true.obs;
  final Rxn<GroupStatsData> data = Rxn<GroupStatsData>();
}
