import 'dart:io';

import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

/// O'rnatilgandan keyin (onboarding / Main) majburiy ruxsatlar.
class AppPermissions {
  AppPermissions._();

  /// v3: bildirishnoma alohida so‘raladi (OEM batch dialogda yo‘qolmasin).
  static const _kRequestedKey = 'core_permissions_requested_v3';

  static Box get _box => Hive.box('user');

  static bool get alreadyRequested =>
      _box.get(_kRequestedKey, defaultValue: false) == true;

  static Future<void> markRequested() => _box.put(_kRequestedKey, true);

  /// Mikrofon, kamera, galereya/fayl, GPS — bildirishnoma alohida.
  static List<Permission> get coreRequired {
    final list = <Permission>[
      Permission.microphone,
      Permission.camera,
      Permission.locationWhenInUse,
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

  static Future<bool> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await permission.request();
    return result.isGranted || result.isLimited;
  }

  /// Faqat kerak bo‘lsa so‘raydi — takroriy dialog yo‘q.
  static Future<bool> ensureMicrophonePermission() async {
    return _requestIfNeeded(Permission.microphone);
  }

  static Future<bool> ensureCameraPermission() async {
    return _requestIfNeeded(Permission.camera);
  }

  static Future<bool> notificationGranted() async {
    final s = await Permission.notification.status;
    return s.isGranted;
  }

  /// Fon/kill rejimida FCM banner uchun — berilmagan bo‘lsa so‘raydi.
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

  /// Ketma-ket so‘raydi; bildirishnoma oxirida alohida (ko‘rinadigan qilib).
  static Future<bool> requestAllRequired() async {
    for (final p in coreRequired) {
      await _requestIfNeeded(p);
    }
    // Bildirishnoma — alohida dialog (Android 13+ POST_NOTIFICATIONS).
    await ensureNotificationPermission();
    await markRequested();
    return allGranted();
  }

  static Future<bool> openAppSettingsIfNeeded() async {
    if (await allGranted()) return true;
    return openAppSettings();
  }
}
