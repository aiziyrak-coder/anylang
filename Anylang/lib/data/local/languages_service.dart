import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../presentation/screens/select_language/select_language_option.dart';
import '../network/languages_repository.dart';

/// Tillar katalogi: API → Hive cache; bayroq URL lar bazadan.
class LanguagesService extends GetxService {
  static const _boxName = 'languages';
  static const _keyItems = 'items_json';
  static const _keyVersion = 'version';
  static const _keyFetchedAt = 'fetched_at_ms';
  static const _staleAfter = Duration(days: 7);

  final LanguagesRepository _repo;
  List<LanguageOption> _memory = const [];
  String? _version;
  bool _refreshing = false;

  LanguagesService({required this._repo});

  List<LanguageOption> get cached =>
      _memory.isNotEmpty ? List.unmodifiable(_memory) : languageOptions;

  Future<LanguagesService> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    await _loadFromDisk();
    if (_memory.isEmpty) {
      await refresh(force: true);
    } else {
      unawaited(refresh(force: true));
    }
    return this;
  }

  LanguageOption? findByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final c = code.toLowerCase();
    for (final o in cached) {
      if (o.langCode == c) return o;
    }
    return languageOptionByCode(c);
  }

  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    if (!force && _memory.isNotEmpty && !_isStale()) return;
    _refreshing = true;
    try {
      final result = await _repo.listLanguages();
      result.when(
        success: (data) {
          final map = data is Map<String, dynamic>
              ? data
              : (data is Map ? Map<String, dynamic>.from(data) : null);
          if (map == null) return;
          final version = map['version']?.toString();
          final rawItems = map['items'];
          final items = (rawItems is List ? rawItems : const <dynamic>[])
              .whereType<Map>()
              .map(_fromApi)
              .whereType<LanguageOption>()
              .toList();
          if (items.isEmpty) return;
          if (!force &&
              version != null &&
              version == _version &&
              _memory.length == items.length) {
            _touchFetchedAt();
            return;
          }
          _memory = items;
          _version = version;
          _saveToDisk(items, version);
        },
        failure: (_) {},
      );
    } finally {
      _refreshing = false;
    }
  }

  LanguageOption? _fromApi(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    final code = (m['code'] as String?)?.trim().toLowerCase() ?? '';
    if (code.isEmpty) return null;
    final local = languageOptionByCode(code);
    final flagCountry =
        ((m['flag_country'] as String?) ?? local?.flagCountry ?? 'uz')
            .toLowerCase();
    final flagUrl = (m['flag_url'] as String?)?.trim();
    return LanguageOption(
      key: local?.key ?? 'lang_name_$code',
      localeCode: local?.localeCode,
      langCode: code,
      nativeName:
          (m['native_name'] as String?)?.trim().isNotEmpty == true
              ? (m['native_name'] as String).trim()
              : (local?.nativeName ?? code),
      flagCountry: flagCountry,
      flagUrl: (flagUrl != null && flagUrl.isNotEmpty)
          ? flagUrl
          : flagUrlForCountry(flagCountry),
      flagEmoji: (m['flag_emoji'] as String?)?.trim().isNotEmpty == true
          ? (m['flag_emoji'] as String).trim()
          : (local?.flagEmoji ?? ''),
    );
  }

  bool _isStale() {
    final box = Hive.box(_boxName);
    final ms = box.get(_keyFetchedAt);
    if (ms is! int) return true;
    final fetched = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(fetched) >= _staleAfter;
  }

  Future<void> _loadFromDisk() async {
    final box = Hive.box(_boxName);
    _version = box.get(_keyVersion)?.toString();
    final raw = box.get(_keyItems);
    if (raw is! String || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _memory = decoded
          .whereType<Map>()
          .map(_fromApi)
          .whereType<LanguageOption>()
          .toList();
    } catch (_) {
      _memory = const [];
    }
  }

  void _saveToDisk(List<LanguageOption> items, String? version) {
    final box = Hive.box(_boxName);
    box.put(
      _keyItems,
      jsonEncode(
        items
            .map(
              (e) => {
                'code': e.langCode,
                'native_name': e.nativeName,
                'flag_country': e.flagCountry,
                'flag_emoji': e.flagEmoji,
                'flag_url': e.flagUrl,
              },
            )
            .toList(),
      ),
    );
    if (version != null) box.put(_keyVersion, version);
    box.put(_keyFetchedAt, DateTime.now().millisecondsSinceEpoch);
  }

  void _touchFetchedAt() {
    Hive.box(_boxName).put(_keyFetchedAt, DateTime.now().millisecondsSinceEpoch);
  }
}
