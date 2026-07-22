import 'package:get/get.dart';

/// Davlat katalogining bitta elementi (ISO alpha-2 + 3 tillik nom).
class CountryOption {
  final String code;
  final String nameUz;
  final String nameRu;
  final String nameEn;
  final String flagEmoji;

  const CountryOption({
    required this.code,
    required this.nameUz,
    required this.nameRu,
    required this.nameEn,
    this.flagEmoji = '',
  });

  /// Joriy UI tiliga mos ko'rinadigan nom.
  String get localizedName {
    final lang = (Get.locale?.languageCode ?? 'uz').toLowerCase();
    return switch (lang) {
      'ru' => nameRu,
      'en' => nameEn,
      _ => nameUz,
    };
  }

  /// Qidiruv / ikkinchi qator: ISO kod.
  String get subtitle => code;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name_uz': nameUz,
        'name_ru': nameRu,
        'name_en': nameEn,
        'flag_emoji': flagEmoji,
      };

  factory CountryOption.fromJson(Map<String, dynamic> json) {
    return CountryOption(
      code: (json['code'] as String? ?? '').toUpperCase(),
      nameUz: (json['name_uz'] as String?) ?? (json['name'] as String?) ?? '',
      nameRu: (json['name_ru'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      flagEmoji: (json['flag_emoji'] as String?) ?? '',
    );
  }
}

/// Offline / API ishlamasa — minimal zaxira ro'yxat.
const List<CountryOption> kFallbackCountries = [
  CountryOption(
    code: 'UZ',
    nameUz: 'Oʻzbekiston',
    nameRu: 'Узбекистан',
    nameEn: 'Uzbekistan',
    flagEmoji: '🇺🇿',
  ),
  CountryOption(
    code: 'KZ',
    nameUz: 'Qozogʻiston',
    nameRu: 'Казахстан',
    nameEn: 'Kazakhstan',
    flagEmoji: '🇰🇿',
  ),
  CountryOption(
    code: 'RU',
    nameUz: 'Rossiya',
    nameRu: 'Россия',
    nameEn: 'Russia',
    flagEmoji: '🇷🇺',
  ),
  CountryOption(
    code: 'TR',
    nameUz: 'Turkiya',
    nameRu: 'Турция',
    nameEn: 'Turkey',
    flagEmoji: '🇹🇷',
  ),
  CountryOption(
    code: 'KG',
    nameUz: 'Qirgʻiziston',
    nameRu: 'Кыргызстан',
    nameEn: 'Kyrgyzstan',
    flagEmoji: '🇰🇬',
  ),
  CountryOption(
    code: 'TJ',
    nameUz: 'Tojikiston',
    nameRu: 'Таджикистан',
    nameEn: 'Tajikistan',
    flagEmoji: '🇹🇯',
  ),
  CountryOption(
    code: 'US',
    nameUz: 'AQSH',
    nameRu: 'США',
    nameEn: 'United States',
    flagEmoji: '🇺🇸',
  ),
  CountryOption(
    code: 'DE',
    nameUz: 'Germaniya',
    nameRu: 'Германия',
    nameEn: 'Germany',
    flagEmoji: '🇩🇪',
  ),
];
