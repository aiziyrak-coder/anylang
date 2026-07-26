import 'dart:async';

import 'package:get/get.dart';

import '../local/session_store.dart';
import 'connectivity_service.dart';
import 'offline_outbox_service.dart';
import 'socket_service.dart';

/// Telegram-uslubidagi tarmoq banner holati.
enum NetworkBannerPhase {
  /// Internet + WS OK — banner yashirin.
  none,

  /// Internet yo‘q — “Tarmoq kutilmoqda…”
  waitingForNetwork,

  /// Internet bor, WS ulanmoqda — “Ulanmoqda…”
  connecting,
}

/// Connectivity + Socket → bitta UI phase; online bo‘lganda flush + WS reconnect.
class ConnectionStatusService extends GetxService {
  final phase = NetworkBannerPhase.none.obs;

  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<SocketStatus>? _socketSub;
  Worker? _onlineWorker;
  Worker? _socketWorker;

  Future<ConnectionStatusService> init() async {
    _recompute();

    if (Get.isRegistered<ConnectivityService>()) {
      final c = Get.find<ConnectivityService>();
      _onlineWorker = ever<bool>(c.online, (_) => _recompute());
      _onlineSub = c.onStatus.listen((online) {
        if (online) {
          _onBackOnline();
        }
        _recompute();
      });
    }

    if (Get.isRegistered<SocketService>()) {
      final s = Get.find<SocketService>();
      _socketWorker = ever<SocketStatus>(s.status, (_) => _recompute());
      _socketSub = s.connection.listen((_) => _recompute());
    }

    return this;
  }

  void _onBackOnline() {
    if (Get.isRegistered<SocketService>()) {
      final sock = Get.find<SocketService>();
      if (!sock.isConnected) {
        unawaited(sock.connect());
      }
    }
    if (Get.isRegistered<OfflineOutboxService>()) {
      unawaited(Get.find<OfflineOutboxService>().flush());
    }
  }

  void _recompute() {
    final token = SessionStore.accessToken;
    final loggedIn =
        token != null && token.isNotEmpty && token != 'none';
    if (!loggedIn) {
      phase.value = NetworkBannerPhase.none;
      return;
    }

    final online = !Get.isRegistered<ConnectivityService>() ||
        Get.find<ConnectivityService>().online.value;

    if (!online) {
      phase.value = NetworkBannerPhase.waitingForNetwork;
      return;
    }

    if (!Get.isRegistered<SocketService>()) {
      phase.value = NetworkBannerPhase.none;
      return;
    }

    final sock = Get.find<SocketService>().status.value;
    if (sock == SocketStatus.connected) {
      phase.value = NetworkBannerPhase.none;
    } else {
      // disconnected / error / connecting — internet bor, ulanish jarayoni
      phase.value = NetworkBannerPhase.connecting;
    }
  }

  @override
  void onClose() {
    _onlineSub?.cancel();
    _socketSub?.cancel();
    _onlineWorker?.dispose();
    _socketWorker?.dispose();
    super.onClose();
  }
}
