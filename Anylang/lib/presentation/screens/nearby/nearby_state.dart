import 'package:get/get.dart';

import 'nearby_person.dart';

class NearbyState extends GetxController {
  final RxBool loading = true.obs;
  final RxBool refreshing = false.obs;
  final RxnString error = RxnString();
  final RxBool locked = false.obs;
  final RxBool sharingEnabled = true.obs;
  final RxBool permissionDenied = false.obs;
  final RxList<NearbyPerson> people = <NearbyPerson>[].obs;
  /// null = barcha tillar
  final RxnString languageFilter = RxnString();
  final RxInt radiusM = 2000.obs;
}
