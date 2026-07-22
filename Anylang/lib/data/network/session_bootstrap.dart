import 'package:get/get.dart';

import '../../data/local/session_store.dart';
import '../../data/network/socket_service.dart';

Future<void> connectRealtimeIfNeeded() async {
  if (!SessionStore.hasSession) return;
  if (!Get.isRegistered<SocketService>()) return;
  final socket = Get.find<SocketService>();
  try {
    await socket.connect();
  } catch (_) {
    // Network may be flaky — chat HTTP still works.
  }
}
