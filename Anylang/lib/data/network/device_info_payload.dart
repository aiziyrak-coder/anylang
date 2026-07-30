import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      if (v.isNotEmpty) {
        version = b.isNotEmpty ? '$v+$b' : v;
        if (version.length > 32) version = version.substring(0, 32);
      }
    } catch (_) {}
    return DeviceInfoPayload(
      deviceId: id,
      deviceName: name,
      deviceType: type,
      platform: _platformLabel(),
      appVersion: version,
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
        if (Platform.isWindows) return 'Windows';
        if (Platform.isMacOS) return 'Mac';
        if (Platform.isLinux) return 'Linux';
        return 'Desktop';
      case 'web':
        return 'Web';
      default:
        return 'Mobile';
    }
  }

  /// Server `DeviceInfoIn.platform` max 64.
  static String _platformLabel() {
    if (kIsWeb) return 'Web';
    try {
      final raw = Platform.operatingSystemVersion.trim();
      if (raw.isEmpty) return Platform.operatingSystem;
      return raw.length <= 64 ? raw : raw.substring(0, 64);
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
