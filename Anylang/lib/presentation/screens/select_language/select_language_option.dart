/// Til tanlash ro'yxatidagi bitta variant.
/// [localeCode] — interfeys tili (uz_UZ / ru_RU / us_US) yoki null
///   (null = interfeys o'zgarmaydi, faqat ona / tarjima tili).
/// [langCode] — ISO 639-1 (har doim).
/// [flagUrl] — serverdagi bayroq PNG (`https://anylang.uz/flags/{cc}.png`).
class LanguageOption {
  final String key;
  final String? localeCode;
  final String langCode;
  final String nativeName;
  final String flagUrl;
  final String flagEmoji;
  final String flagCountry;

  const LanguageOption({
    required this.key,
    required this.localeCode,
    required this.langCode,
    required this.nativeName,
    required this.flagUrl,
    required this.flagEmoji,
    required this.flagCountry,
  });

  /// Eski `flag` asset maydoni — URL.
  String get flag => flagUrl;

  LanguageOption copyWith({
    String? key,
    String? localeCode,
    String? langCode,
    String? nativeName,
    String? flagUrl,
    String? flagEmoji,
    String? flagCountry,
  }) {
    return LanguageOption(
      key: key ?? this.key,
      localeCode: localeCode ?? this.localeCode,
      langCode: langCode ?? this.langCode,
      nativeName: nativeName ?? this.nativeName,
      flagUrl: flagUrl ?? this.flagUrl,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      flagCountry: flagCountry ?? this.flagCountry,
    );
  }
}

const String kFlagsBaseUrl = 'https://anylang.uz/flags';

String flagUrlForCountry(String countryCode) =>
    '$kFlagsBaseUrl/${countryCode.toLowerCase()}.png';

LanguageOption _opt({
  required String key,
  String? localeCode,
  required String langCode,
  required String nativeName,
  required String flagCountry,
  required String flagEmoji,
}) {
  return LanguageOption(
    key: key,
    localeCode: localeCode,
    langCode: langCode,
    nativeName: nativeName,
    flagCountry: flagCountry,
    flagUrl: flagUrlForCountry(flagCountry),
    flagEmoji: flagEmoji,
  );
}

/// Dunyo bo‘ylab mashhur tillar (chat / jonli / ona tili).
/// Interfeys tarjimasi hozircha faqat uz/ru/en — qolganlarda localeCode = null.
final List<LanguageOption> languageOptions = [
  _opt(key: 'lang_name_uz', localeCode: 'uz_UZ', langCode: 'uz', nativeName: 'O‘zbek', flagCountry: 'uz', flagEmoji: '🇺🇿'),
  _opt(key: 'lang_name_en', localeCode: 'us_US', langCode: 'en', nativeName: 'English', flagCountry: 'gb', flagEmoji: '🇬🇧'),
  _opt(key: 'lang_name_ru', localeCode: 'ru_RU', langCode: 'ru', nativeName: 'Русский', flagCountry: 'ru', flagEmoji: '🇷🇺'),
  _opt(key: 'lang_name_tr', langCode: 'tr', nativeName: 'Türkçe', flagCountry: 'tr', flagEmoji: '🇹🇷'),
  _opt(key: 'lang_name_kk', langCode: 'kk', nativeName: 'Қазақша', flagCountry: 'kz', flagEmoji: '🇰🇿'),
  _opt(key: 'lang_name_ky', langCode: 'ky', nativeName: 'Кыргызча', flagCountry: 'kg', flagEmoji: '🇰🇬'),
  _opt(key: 'lang_name_tg', langCode: 'tg', nativeName: 'Тоҷикӣ', flagCountry: 'tj', flagEmoji: '🇹🇯'),
  _opt(key: 'lang_name_az', langCode: 'az', nativeName: 'Azərbaycan', flagCountry: 'az', flagEmoji: '🇦🇿'),
  _opt(key: 'lang_name_tk', langCode: 'tk', nativeName: 'Türkmen', flagCountry: 'tm', flagEmoji: '🇹🇲'),
  _opt(key: 'lang_name_de', langCode: 'de', nativeName: 'Deutsch', flagCountry: 'de', flagEmoji: '🇩🇪'),
  _opt(key: 'lang_name_fr', langCode: 'fr', nativeName: 'Français', flagCountry: 'fr', flagEmoji: '🇫🇷'),
  _opt(key: 'lang_name_es', langCode: 'es', nativeName: 'Español', flagCountry: 'es', flagEmoji: '🇪🇸'),
  _opt(key: 'lang_name_pt', langCode: 'pt', nativeName: 'Português', flagCountry: 'pt', flagEmoji: '🇵🇹'),
  _opt(key: 'lang_name_it', langCode: 'it', nativeName: 'Italiano', flagCountry: 'it', flagEmoji: '🇮🇹'),
  _opt(key: 'lang_name_pl', langCode: 'pl', nativeName: 'Polski', flagCountry: 'pl', flagEmoji: '🇵🇱'),
  _opt(key: 'lang_name_uk', langCode: 'uk', nativeName: 'Українська', flagCountry: 'ua', flagEmoji: '🇺🇦'),
  _opt(key: 'lang_name_nl', langCode: 'nl', nativeName: 'Nederlands', flagCountry: 'nl', flagEmoji: '🇳🇱'),
  _opt(key: 'lang_name_sv', langCode: 'sv', nativeName: 'Svenska', flagCountry: 'se', flagEmoji: '🇸🇪'),
  _opt(key: 'lang_name_no', langCode: 'no', nativeName: 'Norsk', flagCountry: 'no', flagEmoji: '🇳🇴'),
  _opt(key: 'lang_name_da', langCode: 'da', nativeName: 'Dansk', flagCountry: 'dk', flagEmoji: '🇩🇰'),
  _opt(key: 'lang_name_fi', langCode: 'fi', nativeName: 'Suomi', flagCountry: 'fi', flagEmoji: '🇫🇮'),
  _opt(key: 'lang_name_el', langCode: 'el', nativeName: 'Ελληνικά', flagCountry: 'gr', flagEmoji: '🇬🇷'),
  _opt(key: 'lang_name_cs', langCode: 'cs', nativeName: 'Čeština', flagCountry: 'cz', flagEmoji: '🇨🇿'),
  _opt(key: 'lang_name_sk', langCode: 'sk', nativeName: 'Slovenčina', flagCountry: 'sk', flagEmoji: '🇸🇰'),
  _opt(key: 'lang_name_ro', langCode: 'ro', nativeName: 'Română', flagCountry: 'ro', flagEmoji: '🇷🇴'),
  _opt(key: 'lang_name_hu', langCode: 'hu', nativeName: 'Magyar', flagCountry: 'hu', flagEmoji: '🇭🇺'),
  _opt(key: 'lang_name_bg', langCode: 'bg', nativeName: 'Български', flagCountry: 'bg', flagEmoji: '🇧🇬'),
  _opt(key: 'lang_name_sr', langCode: 'sr', nativeName: 'Српски', flagCountry: 'rs', flagEmoji: '🇷🇸'),
  _opt(key: 'lang_name_hr', langCode: 'hr', nativeName: 'Hrvatski', flagCountry: 'hr', flagEmoji: '🇭🇷'),
  _opt(key: 'lang_name_bs', langCode: 'bs', nativeName: 'Bosanski', flagCountry: 'ba', flagEmoji: '🇧🇦'),
  _opt(key: 'lang_name_ar', langCode: 'ar', nativeName: 'العربية', flagCountry: 'sa', flagEmoji: '🇸🇦'),
  _opt(key: 'lang_name_fa', langCode: 'fa', nativeName: 'فارسی', flagCountry: 'ir', flagEmoji: '🇮🇷'),
  _opt(key: 'lang_name_he', langCode: 'he', nativeName: 'עברית', flagCountry: 'il', flagEmoji: '🇮🇱'),
  _opt(key: 'lang_name_ka', langCode: 'ka', nativeName: 'ქართული', flagCountry: 'ge', flagEmoji: '🇬🇪'),
  _opt(key: 'lang_name_hy', langCode: 'hy', nativeName: 'Հայերեն', flagCountry: 'am', flagEmoji: '🇦🇲'),
  _opt(key: 'lang_name_zh', langCode: 'zh', nativeName: '中文', flagCountry: 'cn', flagEmoji: '🇨🇳'),
  _opt(key: 'lang_name_ja', langCode: 'ja', nativeName: '日本語', flagCountry: 'jp', flagEmoji: '🇯🇵'),
  _opt(key: 'lang_name_ko', langCode: 'ko', nativeName: '한국어', flagCountry: 'kr', flagEmoji: '🇰🇷'),
  _opt(key: 'lang_name_hi', langCode: 'hi', nativeName: 'हिन्दी', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_bn', langCode: 'bn', nativeName: 'বাংলা', flagCountry: 'bd', flagEmoji: '🇧🇩'),
  _opt(key: 'lang_name_ur', langCode: 'ur', nativeName: 'اردو', flagCountry: 'pk', flagEmoji: '🇵🇰'),
  _opt(key: 'lang_name_pa', langCode: 'pa', nativeName: 'ਪੰਜਾਬੀ', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_ta', langCode: 'ta', nativeName: 'தமிழ்', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_te', langCode: 'te', nativeName: 'తెలుగు', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_mr', langCode: 'mr', nativeName: 'मराठी', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_gu', langCode: 'gu', nativeName: 'ગુજરાતી', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_kn', langCode: 'kn', nativeName: 'ಕನ್ನಡ', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_ml', langCode: 'ml', nativeName: 'മലയാളം', flagCountry: 'in', flagEmoji: '🇮🇳'),
  _opt(key: 'lang_name_si', langCode: 'si', nativeName: 'සිංහල', flagCountry: 'lk', flagEmoji: '🇱🇰'),
  _opt(key: 'lang_name_ne', langCode: 'ne', nativeName: 'नेपाली', flagCountry: 'np', flagEmoji: '🇳🇵'),
  _opt(key: 'lang_name_th', langCode: 'th', nativeName: 'ไทย', flagCountry: 'th', flagEmoji: '🇹🇭'),
  _opt(key: 'lang_name_vi', langCode: 'vi', nativeName: 'Tiếng Việt', flagCountry: 'vn', flagEmoji: '🇻🇳'),
  _opt(key: 'lang_name_id', langCode: 'id', nativeName: 'Bahasa Indonesia', flagCountry: 'id', flagEmoji: '🇮🇩'),
  _opt(key: 'lang_name_ms', langCode: 'ms', nativeName: 'Bahasa Melayu', flagCountry: 'my', flagEmoji: '🇲🇾'),
  _opt(key: 'lang_name_tl', langCode: 'tl', nativeName: 'Filipino', flagCountry: 'ph', flagEmoji: '🇵🇭'),
  _opt(key: 'lang_name_my', langCode: 'my', nativeName: 'မြန်မာ', flagCountry: 'mm', flagEmoji: '🇲🇲'),
  _opt(key: 'lang_name_km', langCode: 'km', nativeName: 'ខ្មែរ', flagCountry: 'kh', flagEmoji: '🇰🇭'),
  _opt(key: 'lang_name_sw', langCode: 'sw', nativeName: 'Kiswahili', flagCountry: 'ke', flagEmoji: '🇰🇪'),
  _opt(key: 'lang_name_am', langCode: 'am', nativeName: 'አማርኛ', flagCountry: 'et', flagEmoji: '🇪🇹'),
  _opt(key: 'lang_name_ha', langCode: 'ha', nativeName: 'Hausa', flagCountry: 'ng', flagEmoji: '🇳🇬'),
  _opt(key: 'lang_name_yo', langCode: 'yo', nativeName: 'Yorùbá', flagCountry: 'ng', flagEmoji: '🇳🇬'),
];

LanguageOption? languageOptionByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final c = code.toLowerCase();
  for (final o in languageOptions) {
    if (o.langCode == c) return o;
  }
  return null;
}
