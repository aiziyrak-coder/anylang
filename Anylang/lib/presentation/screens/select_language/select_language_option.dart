/// Til tanlash ro'yxatidagi bitta variant.
/// [localeCode] — interfeys tili (uz_UZ / ru_RU / us_US) yoki null.
/// [langCode] — ona tili ISO 639-1 (har doim).
class LanguageOption {
  final String key;
  final String? localeCode;
  final String langCode;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.key,
    required this.localeCode,
    required this.langCode,
    required this.nativeName,
    required this.flag,
  });
}

const List<LanguageOption> languageOptions = [
  LanguageOption(key: 'lang_name_uz', localeCode: 'uz_UZ', langCode: 'uz', nativeName: 'O‘zbek', flag: 'assets/images/flag_uz.png'),
  LanguageOption(key: 'lang_name_en', localeCode: 'us_US', langCode: 'en', nativeName: 'English', flag: 'assets/images/flag_en.png'),
  LanguageOption(key: 'lang_name_ru', localeCode: 'ru_RU', langCode: 'ru', nativeName: 'Русский', flag: 'assets/images/flag_ru.png'),
  LanguageOption(key: 'lang_name_tr', localeCode: null, langCode: 'tr', nativeName: 'Türkçe', flag: 'assets/images/flag_tr.png'),
  LanguageOption(key: 'lang_name_es', localeCode: null, langCode: 'es', nativeName: 'Español', flag: 'assets/images/flag_es.png'),
  LanguageOption(key: 'lang_name_de', localeCode: null, langCode: 'de', nativeName: 'Deutsch', flag: 'assets/images/flag_de.png'),
  LanguageOption(key: 'lang_name_fr', localeCode: null, langCode: 'fr', nativeName: 'Français', flag: 'assets/images/flag_fr.png'),
];
