import '../../utils/screen_options/my_action.dart';
import '../select_language/select_language_option.dart';

/// Faqat Sozlamalar ekraniga xos action'lar.
class SettingsAction extends MyAction {}

/// Bitta bildirishnoma turini yoqish/o'chirish.
class ToggleNotification extends SettingsAction {
  final String key; // 'new_messages' | 'friend_requests' | 'marketing'
  final bool value;
  ToggleNotification(this.key, this.value);
}

/// Til belgilash bottom sheet'idan tanlangan til qaytganda yuboriladi.
class SelectAppLanguage extends SettingsAction {
  final LanguageOption language;
  SelectAppLanguage(this.language);
}

class OpenProfileVisibility extends SettingsAction {}
class OpenBlockedUsers extends SettingsAction {}
class OpenChangePassword extends SettingsAction {}
class OpenEditProfileFromSettings extends SettingsAction {}
class OpenSubscriptionFromSettings extends SettingsAction {}
class OpenNumbersFromSettings extends SettingsAction {}
class SettingsLogoutRequested extends SettingsAction {}

class SettingsDeleteAccountRequested extends SettingsAction {}
