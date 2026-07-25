import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../core/buildNetwork/api_config.dart';

/// Online holat — API host + DNS, debounce bilan (flapping yo‘q).
class ConnectivityService extends GetxService {
  final RxBool online = true.obs;
  Timer? _timer;
  final _onlineCtrl = StreamController<bool>.broadcast();
  int _failStreak = 0;
  Future<bool>? _inFlight;

  Stream<bool> get onStatus => _onlineCtrl.stream;

  Future<ConnectivityService> init() async {
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(refresh());
    });
    return this;
  }

  Future<bool> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _refreshOnce().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<bool> _refreshOnce() async {
    final ok = await probe();
    if (ok) {
      _failStreak = 0;
      if (!online.value) {
        online.value = true;
        _onlineCtrl.add(true);
      } else {
        online.value = true;
      }
    } else {
      _failStreak++;
      // 2 marta ketma-ket fail — offline (qisqa DNS tebranishlarini yutadi).
      if (online.value && _failStreak >= 2) {
        online.value = false;
        _onlineCtrl.add(false);
      }
    }
    return online.value;
  }

  static Future<bool> probe() async {
    final hosts = <String>[];
    final apiHost = Uri.tryParse(kBaseUrl)?.host;
    if (apiHost != null && apiHost.isNotEmpty) hosts.add(apiHost);
    hosts.addAll(const ['one.one.one.one', 'dns.google']);

    for (final host in hosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 2));
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  void onClose() {
    _timer?.cancel();
    _onlineCtrl.close();
    super.onClose();
  }
}

bool isNetworkFailure(Object? err) {
  final s = err?.toString().toLowerCase() ?? '';
  if (s.isEmpty) return false;
  const needles = [
    'socket',
    'connection',
    'network',
    'timed out',
    'timeout',
    'failed host lookup',
    'unreachable',
    'offline',
    'internet',
    'ulanib',
    'ulanish',
    'handshake',
    'broken pipe',
    'connection refused',
    'connection reset',
    'no address',
    'javob bermadi',
    'ssl',
    'certificate',
    'dioexception',
    'clientexception',
    'http request failed',
    'software caused connection abort',
  ];
  for (final n in needles) {
    if (s.contains(n)) return true;
  }
  return false;
}
