import 'package:get/get.dart';

import '../../data/local/session_store.dart';
import '../../data/network/realtime_sync_service.dart';
import '../../data/network/socket_service.dart';

Future<void> connectRealtimeIfNeeded() async {
  if (!SessionStore.hasSession) return;
  if (!Get.isRegistered<SocketService>()) return;
  final socket = Get.find<SocketService>();
  try {
    await socket.connect();
    if (Get.isRegistered<RealtimeSyncService>()) {
      Get.find<RealtimeSyncService>().rebind();
    }
  } catch (_) {
    // Network may be flaky — chat HTTP still works.
  }
}
