import 'dart:convert';

import 'package:hive/hive.dart';

/// Auth sessiyasini Hive `user` box'da saqlash / o'chirish.
class SessionStore {
  SessionStore._();

  static Box get _box => Hive.box('user');

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
    int? expiresInSeconds,
  }) async {
    final fromJwt = _jwtExpMillis(accessToken);
    final expire = fromJwt ??
        DateTime.now()
            .add(Duration(seconds: expiresInSeconds ?? 30 * 60))
            .millisecondsSinceEpoch;

    await _box.put('accessToken', accessToken);
    await _box.put('refreshToken', refreshToken);
    await _box.put('tokenExpireTime', expire);
    if (user != null) {
      await _box.put('user', user);
    }
  }

  static String? get refreshToken => _box.get('refreshToken') as String?;
  static String? get accessToken => _box.get('accessToken') as String?;

  static bool get hasSession {
    final rt = refreshToken;
    return rt != null && rt.isNotEmpty && rt != 'none';
  }

  static Future<void> clear() async {
    await _box.delete('accessToken');
    await _box.delete('refreshToken');
    await _box.delete('tokenExpireTime');
    await _box.delete('user');
  }

  static String appLanguage() {
    final lang = _box.get('language', defaultValue: 'uz_UZ') as String;
    return lang;
  }

  static String nativeLanguage() {
    final stored = _box.get('native_language') as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    final app = appLanguage();
    return app.split('_').first;
  }

  static Map<String, dynamic>? user() {
    final raw = _box.get('user');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static int? userId() {
    final id = user()?['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  static int? _jwtExpMillis(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'];
      if (exp is int) return exp * 1000;
      if (exp is num) return exp.toInt() * 1000;
    } catch (_) {}
    return null;
  }
}
