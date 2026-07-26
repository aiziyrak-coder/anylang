import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../presentation/utils/app_snackbar.dart';

/// Offline chatlar + yuborilmagan xabarlar (Telegram uslubi).
class OfflineChatStore {
  OfflineChatStore._();

  static const _boxName = 'offline_chat';
  static const _keyConversations = 'conversations_json';
  static const _keyOutbox = 'outbox_json';
  static const _keyMessagesPrefix = 'messages_';
  static const _maxCachedMessages = 200;
  static const _maxOutbox = 300;

  static Future<void>? _writeChain;

  static Box get _box => Hive.box(_boxName);

  static Future<void> open() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  /// Ketma-ket yozish — parallel enqueue/remove race'ini oldini oladi.
  static Future<T> _serialized<T>(Future<T> Function() fn) {
    final previous = _writeChain ?? Future<void>.value();
    final gate = Completer<void>();
    _writeChain = gate.future;
    return previous
        .catchError((Object e, StackTrace st) {
          // Oldingi yozuv xatosi zanjirni to'xtatmasin; log qilamiz.
          assert(() {
            // ignore: avoid_print
            print('OfflineChatStore write error: $e\n$st');
            return true;
          }());
        })
        .then((_) async {
          try {
            return await fn();
          } finally {
            gate.complete();
          }
        });
  }

  static Future<void> saveConversations(List<Map<String, dynamic>> items) {
    return _serialized(() async {
      await open();
      await _box.put(_keyConversations, jsonEncode(items));
    });
  }

  static List<Map<String, dynamic>> loadConversations() {
    if (!Hive.isBoxOpen(_boxName)) return const [];
    return _decodeList(_box.get(_keyConversations)?.toString());
  }

  static Future<void> saveMessages(
    int chatId,
    List<Map<String, dynamic>> items,
  ) {
    return _serialized(() async {
      await open();
      final trimmed = items.length <= _maxCachedMessages
          ? items
          : items.sublist(items.length - _maxCachedMessages);
      await _box.put('$_keyMessagesPrefix$chatId', jsonEncode(trimmed));
    });
  }

  static List<Map<String, dynamic>> loadMessages(int chatId) {
    if (!Hive.isBoxOpen(_boxName)) return const [];
    return _decodeList(_box.get('$_keyMessagesPrefix$chatId')?.toString());
  }

  /// Outbox to‘lganida false qaytaradi (eski xabarlarni o‘chirmaydi).
  static Future<bool> tryEnqueueOutbox(Map<String, dynamic> item) async {
    try {
      await enqueueOutbox(item);
      return true;
    } on StateError catch (e) {
      if (e.message == 'OUTBOX_FULL') {
        showAppError('outbox_full'.tr);
        return false;
      }
      rethrow;
    }
  }

  static Future<void> enqueueOutbox(Map<String, dynamic> item) {
    return _serialized(() async {
      await open();
      final list = loadOutbox();
      final clientId = item['client_message_id']?.toString();
      final replacing = clientId != null &&
          clientId.isNotEmpty &&
          list.any((e) => e['client_message_id'] == clientId);
      if (clientId != null && clientId.isNotEmpty) {
        list.removeWhere((e) => e['client_message_id'] == clientId);
      }
      if (!replacing && list.length >= _maxOutbox) {
        throw StateError('OUTBOX_FULL');
      }
      final next = Map<String, dynamic>.from(item);
      next['created_at'] ??= DateTime.now().toIso8601String();
      list.add(next);
      list.sort(_byCreatedAt);
      await _box.put(_keyOutbox, jsonEncode(list));
    });
  }

  static List<Map<String, dynamic>> loadOutbox() {
    if (!Hive.isBoxOpen(_boxName)) return const [];
    final list = _decodeList(_box.get(_keyOutbox)?.toString());
    list.sort(_byCreatedAt);
    return list;
  }

  static Future<void> removeOutbox(String clientMessageId) {
    return _serialized(() async {
      await open();
      final list = loadOutbox()
          .where((e) => e['client_message_id'] != clientMessageId)
          .toList();
      await _box.put(_keyOutbox, jsonEncode(list));
    });
  }

  static List<Map<String, dynamic>> outboxForChat(int chatId) {
    return loadOutbox()
        .where((e) => (e['chat_id'] as num?)?.toInt() == chatId)
        .toList();
  }

  static bool get hasOutbox => loadOutbox().isNotEmpty;

  static int _byCreatedAt(Map<String, dynamic> a, Map<String, dynamic> b) {
    final at = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bt = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return at.compareTo(bt);
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
