import 'package:get/get.dart';

import 'device_session.dart';

class DevicesState extends GetxController {
  final RxBool loading = true.obs;
  final RxBool busy = false.obs;
  final RxnString error = RxnString();
  final RxnString revokingId = RxnString();
  final Rxn<DeviceSession> current = Rxn<DeviceSession>();
  final RxList<DeviceSession> sessions = <DeviceSession>[].obs;
  final RxBool canRevokeOthers = false.obs;
}
