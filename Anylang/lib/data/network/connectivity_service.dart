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

/// Transport / vaqtinchalik server xatolari — outbox va offline UX qayta urinadi.
/// Haqiqiy 4xx validatsiya (masalan, chat topilmadi) bu yerda `false`.
bool isNetworkFailure(Object? err) {
  final s = err?.toString().toLowerCase() ?? '';
  if (s.isEmpty) return false;

  // Bracket error codes from dioToError / AuthValidators.
  const retryCodes = [
    'internal_error',
    'dependency_unavailable',
    'service_unavailable',
    'too_many_requests',
    'gateway_timeout',
    'bad_gateway',
  ];
  for (final code in retryCodes) {
    if (s.contains('[$code]') || s.contains(code)) return true;
  }

  // HTTP status fragments if present in message.
  if (RegExp(r'\b(408|429|500|502|503|504)\b').hasMatch(s)) return true;

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
    // i18n keys / localized server blips (mapDioError)
    'error_timeout',
    'error_ssl',
    'error_connection',
    'error_rate_limited',
    'error_server',
    'server xatosi',
    'server error',
    'ошибка сервера',
    'juda ko‘p urinish',
    'juda kop urinish',
    'too many attempts',
    'слишком много',
    'server javob bermadi',
    'server did not respond',
    'сервер не отвечает',
    'serverga ulanib',
    'could not connect',
    'не удалось подключиться',
  ];
  for (final n in needles) {
    if (s.contains(n)) return true;
  }
  return false;
}
