import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../local/session_store.dart';

/// Login / refresh uchun qurilma meta.
class DeviceInfoPayload {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String platform;
  final String? appVersion;

  const DeviceInfoPayload({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'platform': platform,
        if (appVersion != null && appVersion!.isNotEmpty)
          'app_version': appVersion,
      };

  static Future<DeviceInfoPayload> current() async {
    final id = await SessionStore.ensureDeviceId();
    final type = _deviceType();
    final name = _deviceName(type);
    return DeviceInfoPayload(
      deviceId: id,
      deviceName: name,
      deviceType: type,
      platform: _platformLabel(),
      appVersion: null,
    );
  }

  static String _deviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop';
    }
    return 'mobile';
  }

  static String _deviceName(String type) {
    switch (type) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iPhone';
      case 'desktop':
        return 'Desktop';
      case 'web':
        return 'Web';
      default:
        return 'Mobile';
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'Web';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return Platform.operatingSystem;
    }
  }
}

String generateDeviceId() {
  final r = Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buf.write(r.nextInt(16).toRadixString(16));
  }
  return buf.toString();
}
