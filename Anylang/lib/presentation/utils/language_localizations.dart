import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// UI tarjimalari: `assets/i18n/*.json` + `index.json`.
class LanguageLocalizations extends Translations {
  static const fallbackLocale = Locale('uz', 'UZ');

  static final Map<String, Map<String, String>> _keys = {};
  static final Map<String, String> _canonicalByAlias = {};
  static List<Locale> locales = [fallbackLocale];
  static List<String> langs = ['uz_UZ'];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  @override
  Map<String, Map<String, String>> get keys => _keys;

  /// App startida chaqiriladi — barcha UI tillari yuklanadi.
  static Future<void> load() async {
    if (_loaded && _keys.isNotEmpty) return;

    final indexRaw = await rootBundle.loadString('assets/i18n/index.json');
    final index = jsonDecode(indexRaw) as Map<String, dynamic>;
    final entries = (index['locales'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final nextLocales = <Locale>[];
    final nextLangs = <String>[];
    final nextKeys = <String, Map<String, String>>{};
    final nextCanonicalByAlias = <String, String>{};

    for (final e in entries) {
      final code = (e['code'] as String?)?.trim() ?? '';
      if (code.isEmpty) continue;
      final language = (e['language'] as String?)?.trim() ??
          code.split('_').first.toLowerCase();
      final country = (e['country'] as String?)?.trim() ??
          (code.contains('_') ? code.split('_').last.toUpperCase() : '');
      final aliases = (e['aliases'] as List<dynamic>? ?? const [])
          .map((a) => a.toString())
          .where((a) => a.isNotEmpty)
          .toList();

      Map<String, String> map;
      try {
        final raw = await rootBundle.loadString('assets/i18n/$code.json');
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        map = decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      } catch (_) {
        // Hali generatsiya qilinmagan til — inglizcha fallback.
        final enRaw = await rootBundle.loadString('assets/i18n/us_US.json');
        final decoded = jsonDecode(enRaw) as Map<String, dynamic>;
        map = decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      }

      nextKeys[code] = map;
      nextCanonicalByAlias[code.toLowerCase()] = code;
      for (final a in aliases) {
        nextKeys[a] = map;
        nextCanonicalByAlias[a.toLowerCase().replaceAll('-', '_')] = code;
      }
      // Material/GetX ba'zan faqat languageCode bilan keladi.
      nextKeys.putIfAbsent(language, () => map);
      nextCanonicalByAlias.putIfAbsent(language.toLowerCase(), () => code);

      nextLangs.add(code);
      nextLocales.add(localeFromCode(code, language: language, country: country));
    }

    // Legacy / mismatch aliaslar.
    if (nextKeys.containsKey('us_US')) {
      nextKeys['en'] = nextKeys['us_US']!;
      nextKeys['en_US'] = nextKeys['us_US']!;
      nextKeys['en_GB'] = nextKeys['us_US']!;
    }

    _keys
      ..clear()
      ..addAll(nextKeys);
    _canonicalByAlias
      ..clear()
      ..addAll(nextCanonicalByAlias);
    langs = nextLangs.isEmpty ? ['uz_UZ'] : nextLangs;
    locales = nextLocales.isEmpty ? [fallbackLocale] : nextLocales;
    _loaded = true;
  }

  static String canonicalLocaleCode(String? rawCode) {
    final raw = (rawCode ?? '').trim();
    if (raw.isEmpty) return 'uz_UZ';
    final normalized = raw.replaceAll('-', '_');
    if (_canonicalByAlias.isEmpty) {
      if (normalized.toLowerCase() == 'en_us' ||
          normalized.toLowerCase() == 'en_gb' ||
          normalized.toLowerCase() == 'us_us') {
        return 'us_US';
      }
      if (normalized.contains('_')) return normalized;
    }
    final direct = _canonicalByAlias[normalized.toLowerCase()];
    if (direct != null && direct.isNotEmpty) return direct;

    final parts = normalized.split('_');
    final language = parts.first.toLowerCase();
    final byLang = _canonicalByAlias[language];
    if (byLang != null && byLang.isNotEmpty) return byLang;

    if (normalized.toLowerCase() == 'en_us' ||
        normalized.toLowerCase() == 'en_gb' ||
        normalized.toLowerCase() == 'us_us') {
      return 'us_US';
    }
    return 'uz_UZ';
  }

  /// Hive `us_US` → Flutter `Locale('en','US')`; qolganlari `lang_COUNTRY`.
  static Locale localeFromCode(
    String code, {
    String? language,
    String? country,
  }) {
    final normalized = canonicalLocaleCode(code);
    if (normalized == 'us_US' || normalized.toLowerCase() == 'en_us') {
      return const Locale('en', 'US');
    }
    if (language != null && country != null && country.isNotEmpty) {
      return Locale(language, country);
    }
    final parts = normalized.split('_');
    if (parts.length >= 2) {
      final lang = parts[0].toLowerCase();
      final cc = parts[1].toUpperCase();
      if (lang == 'us') return const Locale('en', 'US');
      return Locale(lang, cc);
    }
    return Locale(parts.first.toLowerCase());
  }

  static void changeLocale(String langCode) {
    final canonical = canonicalLocaleCode(langCode);
    final locale = localeFromCode(canonical);
    Get.updateLocale(locale);
    final box = Hive.box('user');
    box.put('language', canonical);
    final iso = canonical.split('_').first.split('-').first.toLowerCase();
    const aliases = {'us': 'en', 'gb': 'en', 'eng': 'en'};
    box.put('native_language', aliases[iso] ?? iso);
  }
}
