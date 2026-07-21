import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';

import '../core/buildNetwork/api_config.dart';
import '../local/session_store.dart';

/// Secure WebSocket client — Authorization bearer header (query token legacy fallback removed).
/// userId hech qachon URL'da yuborilmaydi (TZ 7.9).
class SocketService extends GetxService with WidgetsBindingObserver {
  static String get _wsBase {
    final http = kBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (http.startsWith('https://')) {
      return 'wss://${http.substring('https://'.length)}';
    }
    if (http.startsWith('http://')) {
      return 'ws://${http.substring('http://'.length)}';
    }
    return 'ws://$http';
  }

  static const Duration _pingInterval = Duration(seconds: 20);
  static const int _maxBackoffSeconds = 20;

  IOWebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  Timer? _clientPingTimer;

  bool _connecting = false;
  bool _manuallyClosed = false;
  int _retry = 0;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController =
      StreamController<SocketStatus>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<SocketStatus> get connection => _connectionController.stream;
  bool get isConnected => _channel != null;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Ulanish — token SessionStore'dan olinadi.
  Future<void> connect({String? accessToken}) async {
    _manuallyClosed = false;
    await _open(forcedToken: accessToken);
  }

  Future<void> _open({String? forcedToken}) async {
    if (_manuallyClosed) return;
    if (_channel != null || _connecting) return;

    final token = forcedToken ?? SessionStore.accessToken;
    if (token == null || token.isEmpty || token == 'none') {
      _log('open() bekor: access token yo\'q');
      return;
    }

    _connecting = true;
    _reconnectTimer?.cancel();
    final uri = Uri.parse('$_wsBase/ws');
    _log('ulanmoqda... #${_retry + 1} -> $uri');

    try {
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: _pingInterval,
      );
      await channel.ready;

      if (_manuallyClosed) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _retry = 0;
      _connectionController.add(SocketStatus.connected);
      _log('ULANDI');

      _clientPingTimer?.cancel();
      _clientPingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        sendRaw({'type': 'ping'});
      });

      _channelSub = channel.stream.listen(
        (event) {
          try {
            final decoded = jsonDecode(event as String) as Map<String, dynamic>;
            if (decoded['type'] == 'pong') return;
            _messageController.add(decoded);
          } catch (e) {
            _log('decode xato: $e');
          }
        },
        onDone: () => _onDrop(SocketStatus.disconnected),
        onError: (_) => _onDrop(SocketStatus.error),
        cancelOnError: true,
      );
    } catch (e) {
      _log('ulanish xato: $e');
      _channel = null;
      _connectionController.add(SocketStatus.error);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onDrop(SocketStatus status) {
    _clientPingTimer?.cancel();
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    _connectionController.add(status);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _retry++;
    final seconds = (2 * _retry).clamp(2, _maxBackoffSeconds).toInt();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_channel == null && !_connecting) _open();
    });
  }

  void sendRaw(Map<String, dynamic> payload) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  void send({required String action, required String topic}) {
    sendRaw({'action': action, 'topic': topic});
  }

  void disconnect() {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _clientPingTimer?.cancel();
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _connectionController.add(SocketStatus.disconnected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_manuallyClosed && _channel == null) {
        _retry = 0;
        _open();
      }
    }
  }

  void _log(String msg) {
    if (kDebugMode) dev.log(msg, name: 'SOCKET');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    _messageController.close();
    _connectionController.close();
    super.onClose();
  }
}

enum SocketStatus { connected, disconnected, error }
