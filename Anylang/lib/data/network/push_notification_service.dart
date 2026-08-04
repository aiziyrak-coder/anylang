import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/local/session_store.dart';
import '../../data/network/device_info_payload.dart';
import '../../data/permissions/app_permissions.dart';
import '../../presentation/screens/chat/chat_payload.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/main/main_state.dart';
import '../core/buildNetwork/network_client.dart';

/// Top-level: background / terminated isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService extends GetxService {
  static const _androidChannelId = 'anylang_push';
  static const _androidChannelName = 'AnyLang';

  final NetworkClient _client;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _ready = false;
  bool _syncing = false;

  PushNotificationService({NetworkClient? client})
      : _client = client ?? Get.find<NetworkClient>();

  Future<PushNotificationService> init() async {
    if (kIsWeb) return this;
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint('Firebase.initializeApp skipped: $e\n$st');
      return this;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.high,
            ),
          );
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
    _tokenSub = messaging.onTokenRefresh.listen((_) => syncToken());

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOpen(initial);
      });
    }

    _ready = true;
    if (SessionStore.hasSession) {
      unawaited(syncToken());
    }
    return this;
  }

  Future<void> syncToken() async {
    if (!_ready || !SessionStore.hasSession || _syncing) return;
    _syncing = true;
    try {
      // Android 13+ POST_NOTIFICATIONS — fon/kill rejimida banner uchun majburiy.
      final notifOk = await AppPermissions.ensureNotificationPermission();
      if (!notifOk) {
        debugPrint('push: notification permission denied');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final device = await DeviceInfoPayload.current();
      final platform = _pushPlatform(device.deviceType);
      await _client.post(
        api: 'api/v1/devices/push-token',
        data: {
          'token': token,
          'device_id': device.deviceId,
          'platform': platform,
          if (device.appVersion != null) 'app_version': device.appVersion,
        },
        notify: SnackNotify.none,
      );
    } catch (e, st) {
      debugPrint('push syncToken failed: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  Future<void> unregister() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      String? token;
      try {
        token = await messaging.getToken();
      } catch (_) {}
      final device = await DeviceInfoPayload.current();
      await _client.delete(
        api: 'api/v1/devices/push-token',
        data: {
          if (token != null && token.isNotEmpty) 'token': token,
          'device_id': device.deviceId,
        },
        notify: SnackNotify.none,
      );
      try {
        await messaging.deleteToken();
      } catch (_) {}
    } catch (e, st) {
      debugPrint('push unregister failed: $e\n$st');
    }
  }

  String _pushPlatform(String deviceType) {
    switch (deviceType) {
      case 'ios':
        return 'ios';
      case 'web':
        return 'web';
      default:
        return 'android';
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final type = message.data['type']?.toString();
    if (type == 'chat_message' &&
        !SessionStore.newMessagesNotificationsEnabled()) {
      return;
    }
    if (type == 'friend_request' &&
        !SessionStore.friendRequestsNotificationsEnabled()) {
      return;
    }

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'AnyLang';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    final payload = jsonEncode(message.data);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _local.show(
      message.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        _navigateFromData(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  void _handleOpen(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'chat_message') {
      final chatId = int.tryParse(data['chat_id']?.toString() ?? '') ?? 0;
      if (chatId <= 0) return;
      final name = data['title']?.toString() ?? 'Chat';
      final ctx = Get.key.currentContext;
      if (ctx == null) return;
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => (ChatScreen()
                ..payload = ChatPayload(
                  chatId: chatId,
                  peerId: 0,
                  name: name,
                  initial: name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  avatarGradient: avatarGradientFor(chatId),
                ))
              .build(),
        ),
      );
      return;
    }
    if (type == 'friend_request') {
      if (Get.isRegistered<MainState>()) {
        Get.find<MainState>().currentTab.value = 1;
      }
    }
  }

  @override
  void onClose() {
    _tokenSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.onClose();
  }
}
