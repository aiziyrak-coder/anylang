import '../../utils/screen_options/my_action.dart';

/// Faqat Select Language ekraniga xos action'lar.
class SelectLanguageAction extends MyAction {}

class SelectLang extends SelectLanguageAction {
  final String key;
  final String? localeCode;
  final String langCode;
  SelectLang(this.key, this.localeCode, this.langCode);
}

class SearchLang extends SelectLanguageAction {
  final String query;
  SearchLang(this.query);
}
