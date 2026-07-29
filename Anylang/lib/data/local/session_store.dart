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
  static const _kSessionId = 'authSessionId';
  static const _kDeviceId = 'deviceId';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Box get _box => Hive.box('user');

  static String? _accessCache;
  static String? _refreshCache;
  static int? _expireCache;
  static String? _sessionIdCache;
  static bool _ready = false;

  /// Ilova startida chaqiriladi — Hive dan secure storage ga migrate qiladi.
  static Future<void> init() async {
    if (_ready) return;
    _accessCache = await _secure.read(key: _kAccess);
    _refreshCache = await _secure.read(key: _kRefresh);
    final expireRaw = await _secure.read(key: _kExpire);
    _expireCache = int.tryParse(expireRaw ?? '');
    _sessionIdCache = await _secure.read(key: _kSessionId);

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
    String? sessionId,
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
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionIdCache = sessionId;
      await _secure.write(key: _kSessionId, value: sessionId);
    }
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
  static String? get sessionId => _sessionIdCache;

  static bool get hasSession {
    final rt = refreshToken;
    return rt != null && rt.isNotEmpty && rt != 'none';
  }

  /// Qurilma ID — bir marta yaratiladi, loginlarda qayta ishlatiladi.
  static Future<String> ensureDeviceId() async {
    final existing = _box.get(_kDeviceId)?.toString();
    if (existing != null && existing.length >= 8) return existing;
    // Local import loopdan qochish — oddiy hex.
    final r = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final id = '${r}a${(r.hashCode & 0xfffffff).toRadixString(16)}';
    await _box.put(_kDeviceId, id);
    return id;
  }

  static Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    _expireCache = null;
    _sessionIdCache = null;
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    await _secure.delete(key: _kExpire);
    await _secure.delete(key: _kSessionId);
    await _clearLegacyTokenKeys();
    await _box.delete('user');
  }

  /// Multi-account: aktiv tokenlarni tozalash (slotda saqlangan holda).
  static Future<void> clearActiveOnly() => clear();

  static Future<void> _clearLegacyTokenKeys() async {
    await _box.delete(_kAccess);
    await _box.delete(_kRefresh);
    await _box.delete(_kExpire);
  }

  static String appLanguage() {
    final lang = _box.get('language', defaultValue: 'uz_UZ') as String;
    return lang;
  }

  static bool get onboardingCompleted =>
      _box.get('onboarding_completed', defaultValue: false) == true;

  static Future<void> setOnboardingCompleted() async {
    await _box.put('onboarding_completed', true);
  }

  /// Tarjima maqsad tili = ona tili (native_language).
  static String preferredLanguage() => nativeLanguage();

  static String nativeLanguage() {
    final stored = _box.get('native_language') as String?;
    if (stored != null && stored.isNotEmpty) {
      return normalizeLangCode(stored);
    }
    final fromUser = user()?['native_language']?.toString();
    if (fromUser != null && fromUser.isNotEmpty) {
      return normalizeLangCode(fromUser);
    }
    // Legacy: faqat app tili bor bo'lsa
    return normalizeLangCode(appLanguage());
  }

  /// ISO 639-1 + UI locale aliaslari (`us_US` → `en`).
  static String normalizeLangCode(String code) {
    final base = code.split('_').first.split('-').first.toLowerCase().trim();
    const aliases = {'us': 'en', 'gb': 'en', 'eng': 'en'};
    if (base.isEmpty) return 'uz';
    return aliases[base] ?? base;
  }

  /// Tizim tili + tarjima tilini birga o'rnatadi (lokal).
  static Future<void> applyAppLanguage({
    required String localeCode,
    required String isoCode,
  }) async {
    final iso = normalizeLangCode(isoCode);
    await _box.put('language', localeCode);
    await _box.put('native_language', iso);
    final u = Map<String, dynamic>.from(user() ?? {});
    u['app_language'] = localeCode;
    u['native_language'] = iso;
    await _box.put('user', u);
  }

  /// Tarjima (chat) tilini alohida o'rnatadi — UI locale o'zgarmaydi.
  static Future<void> applyNativeLanguage(String isoCode) async {
    final iso = normalizeLangCode(isoCode);
    await _box.put('native_language', iso);
    final u = Map<String, dynamic>.from(user() ?? {});
    u['native_language'] = iso;
    await _box.put('user', u);
  }

  static const translationDomains = [
    'general',
    'medical',
    'legal',
    'textile',
    'it',
    'construction',
  ];

  /// Smart Translation soha (medical/legal/…).
  static String translationDomain() {
    final stored = _box.get('translation_domain') as String?;
    if (stored != null && translationDomains.contains(stored)) return stored;
    final fromUser = user()?['translation_domain']?.toString();
    if (fromUser != null && translationDomains.contains(fromUser)) {
      return fromUser;
    }
    return 'general';
  }

  static Future<void> applyTranslationDomain(String domain) async {
    final code = translationDomains.contains(domain) ? domain : 'general';
    await _box.put('translation_domain', code);
    final u = Map<String, dynamic>.from(user() ?? {});
    u['translation_domain'] = code;
    await _box.put('user', u);
  }

  static Map<String, dynamic>? user() {
    final raw = _box.get('user');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Persist refreshed `/users/me` (or login user) without touching tokens.
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _box.put('user', user);
    final native = user['native_language']?.toString();
    if (native != null && native.isNotEmpty) {
      await _box.put('native_language', normalizeLangCode(native));
    }
    final domain = user['translation_domain']?.toString();
    if (domain != null && translationDomains.contains(domain)) {
      await _box.put('translation_domain', domain);
    }
    final app = user['app_language']?.toString();
    if (app != null && app.isNotEmpty) {
      final normalized = app.replaceAll('-', '_').trim();
      if (normalized.contains('_')) {
        await _box.put('language', normalized);
      } else {
        final current = _box.get('language') as String?;
        if (current == null || current.isEmpty) {
          await _box.put('language', normalized);
        }
      }
    }
  }

  static int? userId() {
    final id = user()?['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  static const _kMutedChats = 'muted_chats';
  /// chatId → expiry epoch ms; `0` = forever.
  static const _kMutedChatsUntil = 'muted_chats_until';
  static const _kBlockedUsers = 'blocked_users';

  static Set<String> _stringIdSet(String key) {
    final raw = _box.get(key);
    if (raw is! List) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> _putStringIdSet(String key, Set<String> ids) async {
    await _box.put(key, ids.toList());
  }

  static Map<String, int> _mutedUntilMap() {
    final raw = _box.get(_kMutedChatsUntil);
    final out = <String, int>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key.toString();
        final v = e.value;
        if (k.isEmpty) continue;
        if (v is int) {
          out[k] = v;
        } else if (v is num) {
          out[k] = v.toInt();
        }
      }
    }
    // Legacy boolean set → forever.
    for (final id in _stringIdSet(_kMutedChats)) {
      out.putIfAbsent(id, () => 0);
    }
    return out;
  }

  static Future<void> _putMutedUntilMap(Map<String, int> map) async {
    await _box.put(_kMutedChatsUntil, map);
    // Keep legacy key in sync for older code paths.
    final foreverOrActive = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in map.entries) {
      if (e.value == 0 || e.value > now) foreverOrActive.add(e.key);
    }
    await _putStringIdSet(_kMutedChats, foreverOrActive);
  }

  /// `null` = not muted; `0` = forever; else expiry epoch ms.
  static int? chatMuteUntilMs(int chatId) {
    if (chatId <= 0) return null;
    final until = _mutedUntilMap()['$chatId'];
    if (until == null) return null;
    if (until == 0) return 0;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      // Lazy clear expired (fire-and-forget).
      // ignore: discarded_futures
      setChatMuted(chatId, false);
      return null;
    }
    return until;
  }

  static bool isChatMuted(int chatId) => chatMuteUntilMs(chatId) != null;

  /// [duration] `null` + muted=true → forever.
  static Future<void> setChatMuted(
    int chatId,
    bool muted, {
    Duration? duration,
  }) async {
    if (chatId <= 0) return;
    final map = _mutedUntilMap();
    final key = '$chatId';
    if (!muted) {
      map.remove(key);
    } else if (duration == null) {
      map[key] = 0;
    } else {
      map[key] = DateTime.now().add(duration).millisecondsSinceEpoch;
    }
    await _putMutedUntilMap(map);
  }

  /// Serverdan kelgan mute holatini localga sinxronlash.
  static Future<void> syncChatMuteFromServer(
    int chatId, {
    required bool muted,
    DateTime? mutedUntil,
  }) async {
    if (chatId <= 0) return;
    if (!muted) {
      await setChatMuted(chatId, false);
      return;
    }
    if (mutedUntil == null) {
      await setChatMuted(chatId, true);
      return;
    }
    final remaining = mutedUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      await setChatMuted(chatId, false);
      return;
    }
    await setChatMuted(chatId, true, duration: remaining);
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

  static const _kJonliTtsVoice = 'jonli_tts_voice';
  static const _kJonliTtsSpeed = 'jonli_tts_speed';

  /// Jonli AI ovoz: `female` | `male`.
  static String jonliTtsVoice() {
    final v = _box.get(_kJonliTtsVoice, defaultValue: 'female')?.toString();
    return v == 'male' ? 'male' : 'female';
  }

  static Future<void> setJonliTtsVoice(String value) async {
    final v = value == 'male' ? 'male' : 'female';
    await _box.put(_kJonliTtsVoice, v);
  }

  /// Jonli TTS tezligi 0.5–2.0.
  static double jonliTtsSpeed() {
    final raw = _box.get(_kJonliTtsSpeed, defaultValue: 1.0);
    final n = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 1.0;
    if (n < 0.5) return 0.5;
    if (n > 2.0) return 2.0;
    return n;
  }

  static Future<void> setJonliTtsSpeed(double value) async {
    final n = value.clamp(0.5, 2.0);
    await _box.put(_kJonliTtsSpeed, n);
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
