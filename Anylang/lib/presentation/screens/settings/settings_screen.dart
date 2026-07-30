import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/realtime_sync_service.dart';
import '../../../data/network/socket_service.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/language_localizations.dart';
import '../../utils/legal_urls.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_state_scope.dart';
import '../devices/devices_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../login/login_screen.dart';
import '../profile/profile_account.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../select_language/select_language_option.dart';
import '../subscription/subscription_screen.dart';
import '../numbers/numbers_screen.dart';
import '../support_chat/support_chat_screen.dart';
import '../../modal/simple_list_picker_bottom_sheet.dart';
import 'blocked_users_bottom_sheet.dart';
import 'settings_action.dart';
import 'settings_content.dart';
import 'settings_payload.dart';
import 'settings_state.dart';

class SettingsScreen extends Screen<SettingsState, SettingsPayload> {
  SettingsScreen() : super(mobileContent: SettingsContent());

  static const _visibilityKeys = ['everyone', 'friends', 'nobody'];
  Timer? _chatLangReloadTimer;

  String _visibilityLabel(String key) => 'settings_visibility_$key'.tr;

  void _clearLocalSession() {
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().disconnect();
    }
    SessionStore.clear();
  }

  @override
  void initState(SettingsPayload? payload) {
    try {
      state.focus.value = payload?.focus ?? SettingsFocus.app;
      final native = SessionStore.nativeLanguage();
      final byNative = languageOptions.where((o) => o.langCode == native);
      if (byNative.isNotEmpty) {
        state.currentLanguageKey.value = byNative.first.key;
      } else {
        final locale = Get.locale;
        if (locale != null) {
          final code = '${locale.languageCode}_${locale.countryCode}';
          final match = languageOptionByLocale(code) ??
              languageOptions.firstWhere(
                (o) => o.langCode == locale.languageCode,
                orElse: () => languageOptions.first,
              );
          state.currentLanguageKey.value = match.key;
        }
      }
      state.newMessagesEnabled.value =
          SessionStore.newMessagesNotificationsEnabled();
      state.friendRequestsEnabled.value =
          SessionStore.friendRequestsNotificationsEnabled();
      state.marketingEnabled.value = SessionStore.marketingNotificationsEnabled();
      state.profileVisibilityKey.value = SessionStore.profileVisibility();
      state.translationDomain.value = SessionStore.translationDomain();
    } catch (e, st) {
      debugPrint('SettingsScreen.initState: $e\n$st');
    }
  }

  @override
  void dispose() {
    _chatLangReloadTimer?.cancel();
    _chatLangReloadTimer = null;
    super.dispose();
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
        final localeCode =
            a.language.localeCode ?? uiLocaleCodeFor(a.language.langCode);
        if (localeCode != null) {
          LanguageLocalizations.changeLocale(localeCode);
          await SessionStore.applyAppLanguage(
            localeCode: localeCode,
            isoCode: a.language.langCode,
          );
        } else {
          await SessionStore.applyNativeLanguage(a.language.langCode);
        }
        try {
          final result = await Get.find<ProfileRepository>().updateMe({
            'app_language': SessionStore.appLanguage(),
            'native_language': SessionStore.nativeLanguage(),
          });
          final map = asMap(result.dataOrNull);
          if (map != null) {
            await SessionStore.saveUser(map);
          }
        } catch (_) {
          showAppWarning('settings_language_sync_failed'.tr);
        }
        // Ochiq chat tarixini yangi til bilan qayta yuklash.
        if (ChatStateScope.isRegistered) {
          final chat = ChatStateScope.currentOrNull!;
          final cid = chat.chatId.value;
          if (cid > 0 && Get.isRegistered<ChatRepository>()) {
            Future<void> reload() async {
              final live = ChatStateScope.currentOrNull;
              if (live == null || live.chatId.value != cid) return;
              final page =
                  await Get.find<ChatRepository>().listMessages(cid, limit: 50);
              final liveChat = ChatStateScope.currentOrNull;
              if (liveChat == null || liveChat.chatId.value != cid) return;
              page.when(
                success: (data) {
                  final still = ChatStateScope.currentOrNull;
                  if (still == null || still.chatId.value != cid) return;
                  final me = SessionStore.userId();
                  final raw = asList(data)
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  final mapped = raw
                      .map(
                        (e) => mapChatMessageFromApi(
                          e,
                          me: me,
                          peerName: still.peerName.value,
                        ),
                      )
                      .toList();
                  still.messages.assignAll(mapped);
                },
                failure: (_) {
                  showAppWarning('settings_chat_reload_failed'.tr);
                },
              );
            }

            await reload();
            // Background tarjima tugashi uchun qayta yuklash.
            _chatLangReloadTimer?.cancel();
            _chatLangReloadTimer = Timer(const Duration(seconds: 4), () {
              unawaited(reload());
            });
          }
        }
      case SelectTranslationDomain a:
        final code = SessionStore.translationDomains.contains(a.domain)
            ? a.domain
            : 'general';
        state.translationDomain.value = code;
        await SessionStore.applyTranslationDomain(code);
        try {
          final result = await Get.find<ProfileRepository>().updateMe({
            'translation_domain': code,
          });
          final map = asMap(result.dataOrNull);
          if (map != null) {
            await SessionStore.saveUser(map);
            showAppMessage('settings_smart_translation_saved'.tr);
          }
        } catch (_) {
          showAppWarning('settings_smart_translation_save_failed'.tr);
        }
      case SettingsLogoutRequested _:
        final logout = await Get.find<AuthRepository>().logout();
        if (logout.errorOrNull != null) {
          showAppWarning('logout_failed'.tr);
        } else {
          showAppMessage('settings_logout_success'.tr);
        }
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
                  style: TextStyle(color: context.appColors.danger),
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
            failure: showAppError,
          );
        } catch (e) {
          showAppError(AuthValidators.safeError(e));
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
        // Backend hozircha profile_visibility maydonini qo'llab-quvvatlamaydi — faqat lokal.
        try {
          final sync = await Get.find<ProfileRepository>().updateMe({
            'profile_visibility': key,
          });
          if (sync.errorOrNull != null) {
            showAppWarning('settings_visibility_local_only'.tr);
          }
        } catch (_) {
          showAppWarning('settings_visibility_local_only'.tr);
        }
      case OpenBlockedUsers _:
        await showBlockedUsersBottomSheet(context);
      case OpenChangePassword _:
        // Autentifikatsiyalangan change-password API yo'q — OTP reset.
        // Sessiyali holatda ForgotPasswordScreen Login'ga tashlamaydi.
        navigate(ForgotPasswordScreen());
      case OpenEditProfileFromSettings _:
        final me = await Get.find<ProfileRepository>().getMe();
        final map = asMap(me.dataOrNull);
        if (map == null) {
          showAppError(me.errorOrNull ?? 'profile_load_failed'.tr);
          return;
        }
        final account = ProfileAccount.fromApi(map);
        final isBusiness = map['is_business'] == true;
        if (isBusiness) {
          await navigate(EditBusinessInfoScreen());
        } else {
          await navigate(ProfileEditScreen(), payload: account);
        }
      case OpenSubscriptionFromSettings _:
        await navigate(SubscriptionScreen());
      case OpenNumbersFromSettings _:
        await navigate(NumbersScreen());
      case OpenSupportFromSettings _:
        await navigate(SupportChatScreen());
      case OpenDevicesFromSettings _:
        await navigate(DevicesScreen());
      case OpenPrivacyPolicy _:
        await LegalUrls.openPrivacy();
      case OpenPublicOffer _:
        await LegalUrls.openTerms();
    }
  }
}
