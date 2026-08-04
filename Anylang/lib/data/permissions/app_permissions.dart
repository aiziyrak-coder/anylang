import 'dart:io';

import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

/// O'rnatilgandan keyin (onboarding) majburiy ruxsatlar.
class AppPermissions {
  AppPermissions._();

  /// v2: bildirishnoma (POST_NOTIFICATIONS) ham so'raladi.
  static const _kRequestedKey = 'core_permissions_requested_v2';

  static Box get _box => Hive.box('user');

  static bool get alreadyRequested =>
      _box.get(_kRequestedKey, defaultValue: false) == true;

  static Future<void> markRequested() => _box.put(_kRequestedKey, true);

  /// Mikrofon, kamera, galereya/fayl, GPS, bildirishnomalar.
  static List<Permission> get required {
    final list = <Permission>[
      Permission.microphone,
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.notification,
    ];
    if (Platform.isAndroid) {
      list.add(Permission.photos);
      list.add(Permission.storage); // Android ≤12; 13+ da plugin ignore qiladi
    } else if (Platform.isIOS) {
      list.add(Permission.photos);
    }
    return list;
  }

  static Future<bool> _filesOk() async {
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) return true;
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;
    }
    return false;
  }

  static Future<bool> notificationGranted() async {
    final s = await Permission.notification.status;
    return s.isGranted;
  }

  /// Fon/kill rejimida FCM uchun — har safar MainScreen'da chaqiriladi.
  static Future<bool> ensureNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  static Future<bool> allGranted() async {
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;
    final loc = await Permission.locationWhenInUse.status;
    final notif = await Permission.notification.status;
    if (!mic.isGranted || !cam.isGranted || !loc.isGranted) return false;
    if (!notif.isGranted) return false;
    return _filesOk();
  }

  /// Dialoglarni ketma-ket ochadi.
  static Future<bool> requestAllRequired() async {
    await required.request();
    await markRequested();
    return allGranted();
  }

  static Future<bool> openAppSettingsIfNeeded() async {
    if (await allGranted()) return true;
    return openAppSettings();
  }
}
