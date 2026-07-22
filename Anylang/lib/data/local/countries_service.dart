import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../domain/models/country_option.dart';
import '../core/country_names.dart';
import '../network/countries_repository.dart';

/// Davlatlar katalogi: birinchi ochilishda API → Hive, keyin cache,
/// fonida version o'zgarsa yangilanadi.
class CountriesService extends GetxService {
  static const _boxName = 'countries';
  static const _keyItems = 'items_json';
  static const _keyVersion = 'version';
  static const _keyFetchedAt = 'fetched_at_ms';
  static const _staleAfter = Duration(days: 7);

  final CountriesRepository _repo;
  List<CountryOption> _memory = const [];
  String? _version;
  bool _refreshing = false;

  CountriesService({required this._repo});

  List<CountryOption> get cached =>
      _memory.isNotEmpty ? List.unmodifiable(_memory) : kFallbackCountries;

  Future<CountriesService> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    await _loadFromDisk();
    // Ilova ishga tushganda: bo'sh bo'lsa kutib yukla, aks holda fon yangilash
    if (_memory.isEmpty) {
      await refresh(force: true);
    } else {
      // Cache bor — fonida API version tekshiruvi
      unawaited(refresh(force: true));
    }
    return this;
  }

  Future<List<CountryOption>> getCountries() async {
    if (_memory.isNotEmpty) return List.unmodifiable(_memory);
    await _loadFromDisk();
    if (_memory.isNotEmpty) return List.unmodifiable(_memory);
    await refresh(force: true);
    return List.unmodifiable(_memory.isNotEmpty ? _memory : kFallbackCountries);
  }

  String displayName(String? code) {
    if (code == null || code.isEmpty) return '';
    final name = resolveCountryName(code, catalog: cached);
    return name == '—' ? '' : name;
  }

  CountryOption? findByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final c = code.toUpperCase();
    for (final o in cached) {
      if (o.code == c) return o;
    }
    return null;
  }

  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    // force=false: faqat stale yoki bo'sh bo'lsa tarmoqqa chiqadi
    if (!force && _memory.isNotEmpty && !_isStale()) return;
    _refreshing = true;
    try {
      final result = await _repo.listCountries();
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
              .map((e) => CountryOption.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.code.length == 2)
              .toList();
          if (items.isEmpty) return;
          // Version bir xil va xotira to'liq bo'lsa — yozish shart emas
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
        failure: (_) {
          // Offline — cache / fallback qoladi
        },
      );
    } finally {
      _refreshing = false;
    }
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
          .map((e) => CountryOption.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.code.length == 2)
          .toList();
    } catch (_) {
      _memory = const [];
    }
  }

  void _saveToDisk(List<CountryOption> items, String? version) {
    final box = Hive.box(_boxName);
    box.put(_keyItems, jsonEncode(items.map((e) => e.toJson()).toList()));
    if (version != null) box.put(_keyVersion, version);
    box.put(_keyFetchedAt, DateTime.now().millisecondsSinceEpoch);
  }

  void _touchFetchedAt() {
    Hive.box(_boxName).put(_keyFetchedAt, DateTime.now().millisecondsSinceEpoch);
  }
}
