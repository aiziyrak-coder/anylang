import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'session_store.dart';

/// Bir qurilmadagi saqlangan hisob (tokenlar SecureStorage da).
class AccountSlot {
  final int userId;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? number;
  final bool isBusiness;
  final String planCode;
  final int extraAccountSlots;
  final int maxLocalAccounts;

  const AccountSlot({
    required this.userId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.number,
    this.isBusiness = false,
    this.planCode = 'basic',
    this.extraAccountSlots = 0,
    this.maxLocalAccounts = 3,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'number': number,
        'is_business': isBusiness,
        'plan_code': planCode,
        'extra_account_slots': extraAccountSlots,
        'max_local_accounts': maxLocalAccounts,
      };

  factory AccountSlot.fromJson(Map<String, dynamic> json) {
    return AccountSlot(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      number: json['number']?.toString(),
      isBusiness: json['is_business'] == true,
      planCode: json['plan_code']?.toString() ?? 'basic',
      extraAccountSlots: (json['extra_account_slots'] as num?)?.toInt() ?? 0,
      maxLocalAccounts: (json['max_local_accounts'] as num?)?.toInt() ?? 3,
    );
  }

  factory AccountSlot.fromUserMap(Map<String, dynamic> user) {
    final sub = user['subscription'];
    final plan = sub is Map
        ? (sub['plan']?.toString() ?? 'basic')
        : 'basic';
    final isBiz = user['is_business'] == true || plan == 'business';
    final extras = (user['extra_account_slots'] as num?)?.toInt() ?? 0;
    final maxLocal = (user['max_local_accounts'] as num?)?.toInt() ??
        (isBiz ? (5 + extras).clamp(5, 10) : 3);
    final name = (user['full_name']?.toString() ?? '').trim();
    final company = user['business'] is Map
        ? (user['business']['company_name']?.toString() ?? '').trim()
        : '';
    return AccountSlot(
      userId: (user['id'] as num?)?.toInt() ?? 0,
      email: user['email']?.toString() ?? '',
      displayName: company.isNotEmpty
          ? company
          : (name.isNotEmpty ? name : (user['email']?.toString() ?? 'User')),
      avatarUrl: () {
        final a = (user['avatar_url']?.toString() ?? '').trim();
        if (a.isNotEmpty) return a;
        if (user['business'] is Map) {
          final logo = (user['business']['logo_url']?.toString() ?? '').trim();
          if (logo.isNotEmpty) return logo;
        }
        return null;
      }(),
      number: user['number']?.toString(),
      isBusiness: isBiz,
      planCode: plan,
      extraAccountSlots: extras,
      maxLocalAccounts: maxLocal,
    );
  }

  AccountSlot copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    String? number,
    bool? isBusiness,
    String? planCode,
    int? extraAccountSlots,
    int? maxLocalAccounts,
  }) {
    return AccountSlot(
      userId: userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      number: number ?? this.number,
      isBusiness: isBusiness ?? this.isBusiness,
      planCode: planCode ?? this.planCode,
      extraAccountSlots: extraAccountSlots ?? this.extraAccountSlots,
      maxLocalAccounts: maxLocalAccounts ?? this.maxLocalAccounts,
    );
  }
}

enum AccountAddBlock {
  none,
  needBusiness,
  needBuySlot,
  atHardCap,
}

/// Bir qurilmada bir nechta hisob — tokenlar SecureStorage, meta Hive.
class AccountStore {
  AccountStore._();

  static const _boxName = 'accounts';
  static const _kSlots = 'slots';
  static const _kActiveId = 'active_user_id';
  static const _securePrefix = 'acct_';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Box get _box => Hive.box(_boxName);

  static Future<void> open() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static List<AccountSlot> slots() {
    final raw = _box.get(_kSlots);
    if (raw is! List) return const [];
    final out = <AccountSlot>[];
    for (final e in raw) {
      if (e is Map) {
        final s = AccountSlot.fromJson(Map<String, dynamic>.from(e));
        if (s.userId > 0) out.add(s);
      } else if (e is String) {
        try {
          final decoded = jsonDecode(e);
          if (decoded is Map) {
            final s = AccountSlot.fromJson(Map<String, dynamic>.from(decoded));
            if (s.userId > 0) out.add(s);
          }
        } catch (_) {}
      }
    }
    return out;
  }

  static int? activeUserId() {
    final v = _box.get(_kActiveId);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static AccountSlot? activeSlot() {
    final id = activeUserId() ?? SessionStore.userId();
    if (id == null) return null;
    for (final s in slots()) {
      if (s.userId == id) return s;
    }
    return null;
  }

  /// Entitlement: free=3, business=5+extras (max 10). Eng yaxshi slot bo‘yicha.
  static int maxAllowedSlots() {
    final list = slots();
    var anyBusiness = false;
    var maxExtras = 0;
    var maxFromServer = 3;
    for (final s in list) {
      if (s.isBusiness) anyBusiness = true;
      if (s.extraAccountSlots > maxExtras) maxExtras = s.extraAccountSlots;
      if (s.maxLocalAccounts > maxFromServer) {
        maxFromServer = s.maxLocalAccounts;
      }
    }
    final u = SessionStore.user();
    if (u != null) {
      final fromUser = AccountSlot.fromUserMap(u);
      if (fromUser.isBusiness) anyBusiness = true;
      if (fromUser.extraAccountSlots > maxExtras) {
        maxExtras = fromUser.extraAccountSlots;
      }
      if (fromUser.maxLocalAccounts > maxFromServer) {
        maxFromServer = fromUser.maxLocalAccounts;
      }
    }
    if (!anyBusiness) return 3;
    final computed = (5 + maxExtras).clamp(5, 10);
    return computed > maxFromServer ? computed : maxFromServer.clamp(5, 10);
  }

  static AccountAddBlock addBlockReason() {
    final count = slots().length;
    // Agar joriy sessiyasi slotda yo‘q bo‘lsa ham hisobga olamiz.
    final activeId = SessionStore.userId();
    final effectiveCount = (activeId != null &&
            !slots().any((s) => s.userId == activeId))
        ? count + 1
        : count;
    final max = maxAllowedSlots();
    if (effectiveCount < max) return AccountAddBlock.none;
    if (max >= 10 || effectiveCount >= 10) return AccountAddBlock.atHardCap;
    final anyBiz = slots().any((s) => s.isBusiness) ||
        SessionStore.user()?['is_business'] == true;
    if (!anyBiz) return AccountAddBlock.needBusiness;
    return AccountAddBlock.needBuySlot;
  }

  static bool canAddAccount() => addBlockReason() == AccountAddBlock.none;

  static Future<void> _saveSlots(List<AccountSlot> list) async {
    await _box.put(_kSlots, list.map((e) => e.toJson()).toList());
  }

  static String _sk(int userId, String key) => '$_securePrefix${userId}_$key';

  static Future<void> _writeTokens({
    required int userId,
    required String access,
    required String refresh,
    required int expire,
    String? sessionId,
  }) async {
    await _secure.write(key: _sk(userId, 'access'), value: access);
    await _secure.write(key: _sk(userId, 'refresh'), value: refresh);
    await _secure.write(key: _sk(userId, 'expire'), value: '$expire');
    if (sessionId != null && sessionId.isNotEmpty) {
      await _secure.write(key: _sk(userId, 'session'), value: sessionId);
    }
  }

  static Future<void> _clearTokens(int userId) async {
    await _secure.delete(key: _sk(userId, 'access'));
    await _secure.delete(key: _sk(userId, 'refresh'));
    await _secure.delete(key: _sk(userId, 'expire'));
    await _secure.delete(key: _sk(userId, 'session'));
    await _secure.delete(key: _sk(userId, 'user'));
  }

  static Future<void> _writeUserSnapshot(int userId, Map<String, dynamic> user) async {
    await _secure.write(key: _sk(userId, 'user'), value: jsonEncode(user));
  }

  /// Login / refresh / me yangilanganda — aktiv slotni sinxronlash.
  static Future<void> syncActiveFromSessionStore() async {
    await open();
    if (!SessionStore.hasSession) return;
    final user = SessionStore.user();
    final uid = SessionStore.userId() ??
        (user == null ? null : (user['id'] as num?)?.toInt());
    if (uid == null || uid <= 0) return;

    final access = SessionStore.accessToken;
    final refresh = SessionStore.refreshToken;
    if (access == null || refresh == null) return;

    final expire = SessionStore.tokenExpireTime ??
        DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch;
    await _writeTokens(
      userId: uid,
      access: access,
      refresh: refresh,
      expire: expire,
      sessionId: SessionStore.sessionId,
    );
    if (user != null) {
      await _writeUserSnapshot(uid, user);
    }

    final slot = user != null
        ? AccountSlot.fromUserMap(user)
        : AccountSlot(
            userId: uid,
            email: '',
            displayName: 'User',
          );
    final list = List<AccountSlot>.from(slots());
    final idx = list.indexWhere((s) => s.userId == uid);
    if (idx >= 0) {
      list[idx] = slot;
    } else {
      list.add(slot);
    }
    await _saveSlots(list);
    await _box.put(_kActiveId, uid);
  }

  /// Aktiv hisobni slotga yozib, SessionStore ni bo‘shatadi (logout API emas).
  static Future<void> parkActive() async {
    await syncActiveFromSessionStore();
    // Tokenlarni SessionStore dan olib tashlaymiz, lekin slotda qoladi.
    await SessionStore.clearActiveOnly();
  }

  /// Boshqa hisobga o‘tish — tokenlarni SessionStore ga yuklaydi.
  static Future<bool> activate(int userId) async {
    await open();
    final access = await _secure.read(key: _sk(userId, 'access'));
    final refresh = await _secure.read(key: _sk(userId, 'refresh'));
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        refresh == 'none') {
      return false;
    }
    final expireRaw = await _secure.read(key: _sk(userId, 'expire'));
    final expire = int.tryParse(expireRaw ?? '');
    final sessionId = await _secure.read(key: _sk(userId, 'session'));
    Map<String, dynamic>? user;
    final userRaw = await _secure.read(key: _sk(userId, 'user'));
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(userRaw);
        if (decoded is Map) user = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    // Avval joriyni park qil (agar boshqa bo‘lsa).
    final currentId = SessionStore.userId();
    if (currentId != null && currentId != userId && SessionStore.hasSession) {
      await syncActiveFromSessionStore();
    }

    await SessionStore.saveTokens(
      accessToken: access,
      refreshToken: refresh,
      user: user,
      expiresInSeconds: expire == null
          ? null
          : ((expire - DateTime.now().millisecondsSinceEpoch) / 1000)
              .round()
              .clamp(60, 3600),
      sessionId: sessionId,
    );
    // expire ni aniq yozish — saveTokens JWT dan oladi, lekin fallback.
    await _box.put(_kActiveId, userId);
    return true;
  }

  static Future<void> removeSlot(int userId) async {
    await open();
    final list = slots().where((s) => s.userId != userId).toList();
    await _saveSlots(list);
    await _clearTokens(userId);
    if (activeUserId() == userId) {
      await _box.delete(_kActiveId);
    }
  }

  /// Slotda token bormi.
  static Future<bool> hasTokens(int userId) async {
    final refresh = await _secure.read(key: _sk(userId, 'refresh'));
    return refresh != null && refresh.isNotEmpty && refresh != 'none';
  }

  /// Slot refresh tokeni (server logout uchun).
  static Future<String?> refreshTokenOf(int userId) async {
    return _secure.read(key: _sk(userId, 'refresh'));
  }
}
