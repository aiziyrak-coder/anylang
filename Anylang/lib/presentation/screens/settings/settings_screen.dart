import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/socket_service.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/language_localizations.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../login/login_screen.dart';
import '../select_language/select_language_option.dart';
import '../../modal/simple_list_picker_bottom_sheet.dart';
import 'blocked_users_bottom_sheet.dart';
import 'settings_action.dart';
import 'settings_content.dart';
import 'settings_state.dart';

class SettingsScreen extends Screen<SettingsState, void> {
  SettingsScreen() : super(mobileContent: SettingsContent());

  static const _visibilityKeys = ['everyone', 'friends', 'nobody'];

  String _visibilityLabel(String key) => 'settings_visibility_$key'.tr;

  void _clearLocalSession() {
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().disconnect();
    }
    SessionStore.clear();
  }

  @override
  void initState(void payload) {
    final locale = Get.locale;
    if (locale != null) {
      final code = '${locale.languageCode}_${locale.countryCode}';
      final match = languageOptions.firstWhere(
        (o) => o.localeCode == code,
        orElse: () => languageOptions.first,
      );
      state.currentLanguageKey.value = match.key;
    }
    state.newMessagesEnabled.value = SessionStore.newMessagesNotificationsEnabled();
    state.friendRequestsEnabled.value = SessionStore.friendRequestsNotificationsEnabled();
    state.marketingEnabled.value = SessionStore.marketingNotificationsEnabled();
    state.profileVisibilityKey.value = SessionStore.profileVisibility();
  }

  @override
  Future<void> actionHandler(SettingsState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case ToggleNotification a:
        switch (a.key) {
          case 'new_messages':
            state.newMessagesEnabled.value = a.value;
            await SessionStore.setNewMessagesNotificationsEnabled(a.value);
          case 'friend_requests':
            state.friendRequestsEnabled.value = a.value;
            await SessionStore.setFriendRequestsNotificationsEnabled(a.value);
          case 'marketing':
            state.marketingEnabled.value = a.value;
            await SessionStore.setMarketingNotificationsEnabled(a.value);
        }
      case ChangeThemeMode a:
        Get.find<ThemeController>().setMode(a.mode);
      case SelectAppLanguage a:
        state.currentLanguageKey.value = a.language.key;
        if (a.language.localeCode != null) {
          LanguageLocalizations.changeLocale(a.language.localeCode!);
        }
      case SettingsLogoutRequested _:
        try {
          await Get.find<AuthRepository>().logout();
        } catch (_) {}
        _clearLocalSession();
        navigateAndRemoveUntil(LoginScreen());
      case SettingsDeleteAccountRequested _:
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: Text('settings_delete_account'.tr),
            content: Text('settings_delete_account_confirm'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('settings_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(
                  'settings_delete_account'.tr,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          final result = await Get.find<AuthRepository>().deleteAccount();
          result.when(
            success: (_) {
              _clearLocalSession();
              navigateAndRemoveUntil(LoginScreen());
            },
            failure: (_) {},
          );
        } catch (e) {
          showAppError(e.toString());
        }
      case OpenProfileVisibility _:
        final labels = _visibilityKeys.map(_visibilityLabel).toList();
        final picked = await showSimpleListPickerBottomSheet(
          context,
          title: 'settings_profile_visibility'.tr,
          items: labels,
          selected: _visibilityLabel(state.profileVisibilityKey.value),
        );
        if (picked == null) return;
        final idx = labels.indexOf(picked);
        if (idx < 0) return;
        final key = _visibilityKeys[idx];
        state.profileVisibilityKey.value = key;
        await SessionStore.setProfileVisibility(key);
      case OpenBlockedUsers _:
        await showBlockedUsersBottomSheet(context);
      case OpenChangePassword _:
        navigate(ForgotPasswordScreen());
    }
  }
}
