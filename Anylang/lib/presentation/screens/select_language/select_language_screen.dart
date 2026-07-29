import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../data/local/session_store.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/language_localizations.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/app_snackbar.dart';
import '../login/login_screen.dart';
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
      final match = languageOptionByLocale(code) ??
          languageOptions.firstWhere(
            (o) => o.langCode == locale.languageCode,
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
        try {
          final box = Hive.box('user');
          await box.put('native_language', SessionStore.normalizeLangCode(a.langCode));
          await SessionStore.applyNativeLanguage(SessionStore.normalizeLangCode(a.langCode));
        } catch (_) {
          showAppError('select_language_hive_error'.tr);
        }
        final localeCode = a.localeCode ?? uiLocaleCodeFor(a.langCode);
        if (localeCode != null) {
          LanguageLocalizations.changeLocale(localeCode);
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
        try {
          final box = Hive.box('user');
          final iso = SessionStore.normalizeLangCode(selected.langCode);
          await box.put('native_language', iso);
          await SessionStore.applyNativeLanguage(iso);
        } catch (_) {
          showAppError('select_language_hive_error'.tr);
          return;
        }
        final localeCode =
            selected.localeCode ?? uiLocaleCodeFor(selected.langCode);
        if (localeCode != null) {
          LanguageLocalizations.changeLocale(localeCode);
          await SessionStore.applyAppLanguage(
            localeCode: localeCode,
            isoCode: selected.langCode,
          );
        }
        if (SessionStore.onboardingCompleted) {
          navigate(LoginScreen());
        } else {
          navigate(OnboardingScreen());
        }
    }
  }
}
