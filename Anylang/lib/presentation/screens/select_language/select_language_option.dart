/// Til tanlash ro'yxatidagi bitta variant.
/// [localeCode] — interfeys tili (uz_UZ / ru_RU / us_US / tr_TR / …).
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

/// ISO til → UI locale (Hive / GetX kaliti).
String? uiLocaleCodeFor(String langCode) {
  final c = langCode.toLowerCase().trim();
  const map = <String, String>{
    'uz': 'uz_UZ',
    'en': 'us_US',
    'ru': 'ru_RU',
    'tr': 'tr_TR',
    'kk': 'kk_KZ',
    'ky': 'ky_KG',
    'tg': 'tg_TJ',
    'az': 'az_AZ',
    'tk': 'tk_TM',
    'de': 'de_DE',
    'fr': 'fr_FR',
    'es': 'es_ES',
    'pt': 'pt_PT',
    'it': 'it_IT',
    'pl': 'pl_PL',
    'uk': 'uk_UA',
    'nl': 'nl_NL',
    'sv': 'sv_SE',
    'no': 'no_NO',
    'nb': 'no_NO',
    'da': 'da_DK',
    'fi': 'fi_FI',
    'el': 'el_GR',
    'cs': 'cs_CZ',
    'sk': 'sk_SK',
    'ro': 'ro_RO',
    'hu': 'hu_HU',
    'bg': 'bg_BG',
    'sr': 'sr_RS',
    'hr': 'hr_HR',
    'bs': 'bs_BA',
    'ar': 'ar_SA',
    'fa': 'fa_IR',
    'he': 'he_IL',
    'ka': 'ka_GE',
    'hy': 'hy_AM',
    'zh': 'zh_CN',
    'ja': 'ja_JP',
    'ko': 'ko_KR',
    'hi': 'hi_IN',
    'bn': 'bn_BD',
    'ur': 'ur_PK',
    'pa': 'pa_IN',
    'ta': 'ta_IN',
    'te': 'te_IN',
    'mr': 'mr_IN',
    'gu': 'gu_IN',
    'kn': 'kn_IN',
    'ml': 'ml_IN',
    'si': 'si_LK',
    'ne': 'ne_NP',
    'th': 'th_TH',
    'vi': 'vi_VN',
    'id': 'id_ID',
    'ms': 'ms_MY',
    'tl': 'tl_PH',
    'fil': 'tl_PH',
    'my': 'my_MM',
    'km': 'km_KH',
    'sw': 'sw_KE',
    'am': 'am_ET',
    'ha': 'ha_NG',
    'yo': 'yo_NG',
    'mn': 'mn_MN',
    'sq': 'sq_AL',
    'lt': 'lt_LT',
    'lv': 'lv_LV',
    'et': 'et_EE',
    'sl': 'sl_SI',
    'mk': 'mk_MK',
    'be': 'be_BY',
    'af': 'af_ZA',
    'ca': 'ca_ES',
    'is': 'is_IS',
    'ga': 'ga_IE',
    'mt': 'mt_MT',
    'cy': 'cy_GB',
    'ps': 'ps_AF',
    'ku': 'ku_TR',
    'so': 'so_SO',
    'zu': 'zu_ZA',
    'ig': 'ig_NG',
  };
  return map[c];
}

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
    localeCode: localeCode ?? uiLocaleCodeFor(langCode),
    langCode: langCode,
    nativeName: nativeName,
    flagCountry: flagCountry,
    flagUrl: flagUrlForCountry(flagCountry),
    flagEmoji: flagEmoji,
  );
}

/// Dunyo tillari — har biri to‘liq UI locale bilan.
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
  // Qo‘shimcha tillar
  _opt(key: 'lang_name_mn', langCode: 'mn', nativeName: 'Монгол', flagCountry: 'mn', flagEmoji: '🇲🇳'),
  _opt(key: 'lang_name_sq', langCode: 'sq', nativeName: 'Shqip', flagCountry: 'al', flagEmoji: '🇦🇱'),
  _opt(key: 'lang_name_lt', langCode: 'lt', nativeName: 'Lietuvių', flagCountry: 'lt', flagEmoji: '🇱🇹'),
  _opt(key: 'lang_name_lv', langCode: 'lv', nativeName: 'Latviešu', flagCountry: 'lv', flagEmoji: '🇱🇻'),
  _opt(key: 'lang_name_et', langCode: 'et', nativeName: 'Eesti', flagCountry: 'ee', flagEmoji: '🇪🇪'),
  _opt(key: 'lang_name_sl', langCode: 'sl', nativeName: 'Slovenščina', flagCountry: 'si', flagEmoji: '🇸🇮'),
  _opt(key: 'lang_name_mk', langCode: 'mk', nativeName: 'Македонски', flagCountry: 'mk', flagEmoji: '🇲🇰'),
  _opt(key: 'lang_name_be', langCode: 'be', nativeName: 'Беларуская', flagCountry: 'by', flagEmoji: '🇧🇾'),
  _opt(key: 'lang_name_af', langCode: 'af', nativeName: 'Afrikaans', flagCountry: 'za', flagEmoji: '🇿🇦'),
  _opt(key: 'lang_name_ca', langCode: 'ca', nativeName: 'Català', flagCountry: 'es', flagEmoji: '🇪🇸'),
  _opt(key: 'lang_name_is', langCode: 'is', nativeName: 'Íslenska', flagCountry: 'is', flagEmoji: '🇮🇸'),
  _opt(key: 'lang_name_ga', langCode: 'ga', nativeName: 'Gaeilge', flagCountry: 'ie', flagEmoji: '🇮🇪'),
  _opt(key: 'lang_name_mt', langCode: 'mt', nativeName: 'Malti', flagCountry: 'mt', flagEmoji: '🇲🇹'),
  _opt(key: 'lang_name_cy', langCode: 'cy', nativeName: 'Cymraeg', flagCountry: 'gb', flagEmoji: '🇬🇧'),
  _opt(key: 'lang_name_ps', langCode: 'ps', nativeName: 'پښتو', flagCountry: 'af', flagEmoji: '🇦🇫'),
  _opt(key: 'lang_name_ku', langCode: 'ku', nativeName: 'Kurdî', flagCountry: 'iq', flagEmoji: '🇮🇶'),
  _opt(key: 'lang_name_so', langCode: 'so', nativeName: 'Soomaali', flagCountry: 'so', flagEmoji: '🇸🇴'),
  _opt(key: 'lang_name_zu', langCode: 'zu', nativeName: 'isiZulu', flagCountry: 'za', flagEmoji: '🇿🇦'),
  _opt(key: 'lang_name_ig', langCode: 'ig', nativeName: 'Igbo', flagCountry: 'ng', flagEmoji: '🇳🇬'),
];

LanguageOption? languageOptionByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final c = code.toLowerCase();
  for (final o in languageOptions) {
    if (o.langCode == c) return o;
  }
  return null;
}

LanguageOption? languageOptionByLocale(String? localeCode) {
  if (localeCode == null || localeCode.isEmpty) return null;
  final n = localeCode.replaceAll('-', '_');
  for (final o in languageOptions) {
    if (o.localeCode == n) return o;
  }
  // en_US → us_US
  if (n == 'en_US' || n == 'en_GB') {
    return languageOptionByCode('en');
  }
  return null;
}
