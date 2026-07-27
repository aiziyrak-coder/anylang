import 'dart:convert';

import 'package:hive/hive.dart';

/// Boshqa foydalanuvchilarning public profil JSON cache (Hive).
class PublicProfileCache {
  PublicProfileCache._();

  static const _boxName = 'public_profiles';
  static const _keyPrefix = 'u_';
  static const _maxEntries = 80;

  static Box get _box => Hive.box(_boxName);

  static Future<void> open() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static String _key(int userId) => '$_keyPrefix$userId';

  static Map<String, dynamic>? get(int userId) {
    if (userId <= 0 || !Hive.isBoxOpen(_boxName)) return null;
    final raw = _box.get(_key(userId))?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> put(int userId, Map<String, dynamic> json) async {
    if (userId <= 0) return;
    await open();
    await _box.put(_key(userId), jsonEncode(json));
    await _trimIfNeeded();
  }

  static Future<void> _trimIfNeeded() async {
    if (_box.length <= _maxEntries) return;
    // Eng eski kalitlarni o‘chirish (Hive tartibi insertion ga yaqin).
    final keys = _box.keys.toList();
    final overflow = keys.length - _maxEntries;
    for (var i = 0; i < overflow; i++) {
      await _box.delete(keys[i]);
    }
  }
}
