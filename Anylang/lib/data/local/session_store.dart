import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Auth sessiyasi: JWT lar [FlutterSecureStorage] da (Keystore/Keychain),
/// profil kabi maxfiy bo'lmagan ma'lumotlar Hive `user` box'da.
class SessionStore {
  SessionStore._();

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';
  static const _kExpire = 'tokenExpireTime';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Box get _box => Hive.box('user');

  static String? _accessCache;
  static String? _refreshCache;
  static int? _expireCache;
  static bool _ready = false;

  /// Ilova startida chaqiriladi — Hive dan secure storage ga migrate qiladi.
  static Future<void> init() async {
    if (_ready) return;
    _accessCache = await _secure.read(key: _kAccess);
    _refreshCache = await _secure.read(key: _kRefresh);
    final expireRaw = await _secure.read(key: _kExpire);
    _expireCache = int.tryParse(expireRaw ?? '');

    // Legacy plaintext Hive → secure migration
    final legacyAccess = _box.get(_kAccess) as String?;
    final legacyRefresh = _box.get(_kRefresh) as String?;
    if ((_accessCache == null || _accessCache!.isEmpty) &&
        legacyAccess != null &&
        legacyAccess.isNotEmpty &&
        legacyAccess != 'none') {
      await saveTokens(
        accessToken: legacyAccess,
        refreshToken: legacyRefresh ?? 'none',
        expiresInSeconds: null,
      );
    } else {
      await _clearLegacyTokenKeys();
    }
    _ready = true;
  }

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

    _accessCache = accessToken;
    _refreshCache = refreshToken;
    _expireCache = expire;

    await _secure.write(key: _kAccess, value: accessToken);
    await _secure.write(key: _kRefresh, value: refreshToken);
    await _secure.write(key: _kExpire, value: '$expire');
    await _clearLegacyTokenKeys();

    if (user != null) {
      await _box.put('user', user);
      final native = user['native_language']?.toString();
      if (native != null && native.isNotEmpty) {
        await _box.put('native_language', normalizeLangCode(native));
      }
    }
  }

  static String? get refreshToken => _refreshCache;
  static String? get accessToken => _accessCache;
  static int? get tokenExpireTime => _expireCache;

  static bool get hasSession {
    final rt = refreshToken;
    return rt != null && rt.isNotEmpty && rt != 'none';
  }

  static Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    _expireCache = null;
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    await _secure.delete(key: _kExpire);
    await _clearLegacyTokenKeys();
    await _box.delete('user');
  }

  static Future<void> _clearLegacyTokenKeys() async {
    await _box.delete(_kAccess);
    await _box.delete(_kRefresh);
    await _box.delete(_kExpire);
  }

  static String appLanguage() {
    final lang = _box.get('language', defaultValue: 'uz_UZ') as String;
    return lang;
  }

  static String nativeLanguage() {
    final stored = _box.get('native_language') as String?;
    if (stored != null && stored.isNotEmpty) {
      return normalizeLangCode(stored);
    }
    final fromUser = user()?['native_language']?.toString();
    if (fromUser != null && fromUser.isNotEmpty) {
      return normalizeLangCode(fromUser);
    }
    return normalizeLangCode(appLanguage());
  }

  /// ISO 639-1 + UI locale aliaslari (`us_US` → `en`).
  static String normalizeLangCode(String code) {
    final base = code.split('_').first.split('-').first.toLowerCase().trim();
    const aliases = {'us': 'en', 'gb': 'en', 'eng': 'en'};
    if (base.isEmpty) return 'uz';
    return aliases[base] ?? base;
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

  static const _kMutedChats = 'muted_chats';
  static const _kBlockedUsers = 'blocked_users';

  static Set<String> _stringIdSet(String key) {
    final raw = _box.get(key);
    if (raw is! List) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> _putStringIdSet(String key, Set<String> ids) async {
    await _box.put(key, ids.toList());
  }

  static bool isChatMuted(int chatId) =>
      chatId > 0 && _stringIdSet(_kMutedChats).contains('$chatId');

  static Future<void> setChatMuted(int chatId, bool muted) async {
    if (chatId <= 0) return;
    final ids = _stringIdSet(_kMutedChats);
    if (muted) {
      ids.add('$chatId');
    } else {
      ids.remove('$chatId');
    }
    await _putStringIdSet(_kMutedChats, ids);
  }

  static bool isUserBlocked(int userId) =>
      userId > 0 && _stringIdSet(_kBlockedUsers).contains('$userId');

  static Future<void> setUserBlocked(int userId, bool blocked) async {
    if (userId <= 0) return;
    final ids = _stringIdSet(_kBlockedUsers);
    if (blocked) {
      ids.add('$userId');
    } else {
      ids.remove('$userId');
    }
    await _putStringIdSet(_kBlockedUsers, ids);
  }

  static List<int> blockedUserIds() {
    return _stringIdSet(_kBlockedUsers)
        .map(int.tryParse)
        .whereType<int>()
        .where((id) => id > 0)
        .toList()
      ..sort();
  }

  static const _kNotifNewMessages = 'notif_new_messages';
  static const _kNotifFriendRequests = 'notif_friend_requests';
  static const _kNotifMarketing = 'notif_marketing';
  static const _kProfileVisibility = 'profile_visibility';

  static bool notificationEnabled(String key, {bool defaultValue = true}) {
    final stored = _box.get(key);
    if (stored is bool) return stored;
    return defaultValue;
  }

  static Future<void> setNotificationEnabled(String key, bool value) async {
    await _box.put(key, value);
  }

  static bool newMessagesNotificationsEnabled() =>
      notificationEnabled(_kNotifNewMessages);

  static bool friendRequestsNotificationsEnabled() =>
      notificationEnabled(_kNotifFriendRequests);

  static bool marketingNotificationsEnabled() =>
      notificationEnabled(_kNotifMarketing, defaultValue: false);

  static Future<void> setNewMessagesNotificationsEnabled(bool value) =>
      setNotificationEnabled(_kNotifNewMessages, value);

  static Future<void> setFriendRequestsNotificationsEnabled(bool value) =>
      setNotificationEnabled(_kNotifFriendRequests, value);

  static Future<void> setMarketingNotificationsEnabled(bool value) =>
      setNotificationEnabled(_kNotifMarketing, value);

  static String profileVisibility() =>
      _box.get(_kProfileVisibility, defaultValue: 'everyone') as String;

  static Future<void> setProfileVisibility(String value) async {
    await _box.put(_kProfileVisibility, value);
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
