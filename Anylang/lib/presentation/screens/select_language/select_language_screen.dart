import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../data/local/session_store.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/language_localizations.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'select_language_action.dart';
import 'select_language_content.dart';
import 'select_language_option.dart';
import 'select_language_state.dart';

class SelectLanguageScreen extends Screen<SelectLanguageState, void> {

  SelectLanguageScreen() : super(
    mobileContent: SelectLanguageContent(),
  );

  @override
  void initState(void payload) {
    final locale = Get.locale;
    if (locale != null) {
      final code = '${locale.languageCode}_${locale.countryCode}';
      final match = languageOptions.firstWhere(
        (o) => o.localeCode == code,
        orElse: () => languageOptions.first,
      );
      state.selectedKey.value = match.key;
    }
  }

  @override
  Future<void> actionHandler(SelectLanguageState state, MyAction action) async {
    switch (action) {
      case SelectLang a:
        state.selectedKey.value = a.key;
        final box = Hive.box('user');
        await box.put('native_language', SessionStore.normalizeLangCode(a.langCode));
        if (a.localeCode != null) {
          LanguageLocalizations.changeLocale(a.localeCode!);
        }
      case SearchLang a:
        state.query.value = a.query;
      case ChangeThemeMode a:
        Get.find<ThemeController>().setMode(a.mode);
      case Continue _:
        final selected = languageOptions.firstWhere(
          (o) => o.key == state.selectedKey.value,
          orElse: () => languageOptions.first,
        );
        final box = Hive.box('user');
        await box.put('native_language', SessionStore.normalizeLangCode(selected.langCode));
        if (selected.localeCode != null) {
          LanguageLocalizations.changeLocale(selected.localeCode!);
        }
        navigate(OnboardingScreen());
    }
  }
}
