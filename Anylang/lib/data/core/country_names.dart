import 'package:get/get.dart';

import '../../domain/models/country_option.dart';

const Map<String, String> kCountryNamesUz = {
  'UZ': 'Oʻzbekiston',
  'KZ': 'Qozogʻiston',
  'KG': 'Qirgʻiziston',
  'TJ': 'Tojikiston',
  'TM': 'Turkmaniston',
  'RU': 'Rossiya',
  'TR': 'Turkiya',
  'AZ': 'Ozarbayjon',
  'US': 'AQSH',
  'GB': 'Buyuk Britaniya',
  'DE': 'Germaniya',
  'FR': 'Fransiya',
  'IT': 'Italiya',
  'ES': 'Ispaniya',
  'CN': 'Xitoy',
  'JP': 'Yaponiya',
  'KR': 'Janubiy Koreya',
  'IN': 'Hindiston',
  'AE': 'BAA',
  'SA': 'Saudiya Arabistoni',
  'CA': 'Kanada',
  'AU': 'Avstraliya',
  'PL': 'Polsha',
  'UA': 'Ukraina',
  'BY': 'Belarus',
  'NL': 'Niderlandiya',
  'SE': 'Shvetsiya',
  'CH': 'Shveysariya',
  'MY': 'Malayziya',
  'ID': 'Indoneziya',
};

const Map<String, String> kCountryNamesRu = {
  'UZ': 'Узбекистан',
  'KZ': 'Казахстан',
  'KG': 'Кыргызстан',
  'TJ': 'Таджикистан',
  'TM': 'Туркменистан',
  'RU': 'Россия',
  'TR': 'Турция',
  'AZ': 'Азербайджан',
  'US': 'США',
  'GB': 'Великобритания',
  'DE': 'Германия',
  'FR': 'Франция',
  'IT': 'Италия',
  'ES': 'Испания',
  'CN': 'Китай',
  'JP': 'Япония',
  'KR': 'Южная Корея',
  'IN': 'Индия',
  'AE': 'ОАЭ',
  'SA': 'Саудовская Аравия',
  'CA': 'Канада',
  'AU': 'Австралия',
  'PL': 'Польша',
  'UA': 'Украина',
  'BY': 'Беларусь',
  'NL': 'Нидерланды',
  'SE': 'Швеция',
  'CH': 'Швейцария',
  'MY': 'Малайзия',
  'ID': 'Индонезия',
};

const Map<String, String> kCountryNamesEn = {
  'UZ': 'Uzbekistan',
  'KZ': 'Kazakhstan',
  'KG': 'Kyrgyzstan',
  'TJ': 'Tajikistan',
  'TM': 'Turkmenistan',
  'RU': 'Russia',
  'TR': 'Turkey',
  'AZ': 'Azerbaijan',
  'US': 'United States',
  'GB': 'United Kingdom',
  'DE': 'Germany',
  'FR': 'France',
  'IT': 'Italy',
  'ES': 'Spain',
  'CN': 'China',
  'JP': 'Japan',
  'KR': 'South Korea',
  'IN': 'India',
  'AE': 'United Arab Emirates',
  'SA': 'Saudi Arabia',
  'CA': 'Canada',
  'AU': 'Australia',
  'PL': 'Poland',
  'UA': 'Ukraine',
  'BY': 'Belarus',
  'NL': 'Netherlands',
  'SE': 'Sweden',
  'CH': 'Switzerland',
  'MY': 'Malaysia',
  'ID': 'Indonesia',
};

Map<String, String> _namesForLocale() {
  final lang = (Get.locale?.languageCode ?? 'uz').toLowerCase();
  return switch (lang) {
    'ru' => kCountryNamesRu,
    'en' => kCountryNamesEn,
    _ => kCountryNamesUz,
  };
}

/// ISO alpha-2 → to'liq davlat nomi. Kodning o'zi qaytmaydi (agar ma'lum bo'lsa).
String resolveCountryName(
  String? codeOrName, {
  List<CountryOption>? catalog,
}) {
  if (codeOrName == null || codeOrName.trim().isEmpty) return '—';
  final raw = codeOrName.trim();
  if (raw.length != 2) return raw;

  final c = raw.toUpperCase();
  if (catalog != null) {
    for (final o in catalog) {
      if (o.code == c) {
        final n = o.localizedName.trim();
        // Bo'sh yoki faqat kod bo'lsa — statik xaritaga o'tamiz
        if (n.isNotEmpty && n.toUpperCase() != c) return n;
        break;
      }
    }
  }
  return _namesForLocale()[c] ?? c;
}
