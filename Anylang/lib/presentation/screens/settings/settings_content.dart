import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../modal/language_bottom_sheet.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/danger_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/info_row.dart';
import '../../ui/items/toggle_row.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme_selector.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'settings_action.dart';
import 'settings_state.dart';

/// S15 — Sozlamalar. Umumiy, Ko'rinish (tema), Bildirishnomalar,
/// Maxfiylik & hisob bo'limlari + hisobdan chiqish.
class SettingsContent extends ScreenContent<SettingsState> {
  String _visibilityLabel(String key) => 'settings_visibility_$key'.tr;

  @override
  Widget build(BuildContext context, SettingsState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(title: 'settings_title'.tr, onBack: () => sendAction(Back())),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 24.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(c, 'settings_general'.tr),
                    SizedBox(height: 9.dp),
                    _card(c, [
                      Obx(() => InfoRow(
                            icon: Icons.public,
                            label: 'settings_app_language'.tr,
                            value: state.currentLanguageKey.value.tr,
                            showChevron: true,
                            onTap: () => _openAppLanguage(context, state, sendAction),
                          )),
                    ], padHorizontal: false),
                    SizedBox(height: 20.dp),
                    _sectionLabel(c, 'settings_appearance'.tr),
                    SizedBox(height: 9.dp),
                    _card(c, [
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.dp),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'settings_theme'.tr,
                            style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      ThemeSelector(onSelect: (mode) => sendAction(ChangeThemeMode(mode))),
                    ], divide: false),
                    SizedBox(height: 20.dp),
                    _sectionLabel(c, 'settings_notifications'.tr),
                    SizedBox(height: 9.dp),
                    _card(c, [
                      Obx(() => ToggleRow(
                            label: 'settings_notif_messages'.tr,
                            value: state.newMessagesEnabled.value,
                            onChanged: (v) => sendAction(ToggleNotification('new_messages', v)),
                          )),
                      Obx(() => ToggleRow(
                            label: 'settings_notif_friend_requests'.tr,
                            value: state.friendRequestsEnabled.value,
                            onChanged: (v) => sendAction(ToggleNotification('friend_requests', v)),
                          )),
                      Obx(() => ToggleRow(
                            label: 'settings_notif_marketing'.tr,
                            value: state.marketingEnabled.value,
                            onChanged: (v) => sendAction(ToggleNotification('marketing', v)),
                          )),
                    ]),
                    SizedBox(height: 20.dp),
                    _sectionLabel(c, 'settings_privacy'.tr),
                    SizedBox(height: 9.dp),
                    _card(c, [
                      Obx(() => InfoRow(
                            icon: Icons.visibility_outlined,
                            label: 'settings_profile_visibility'.tr,
                            value: _visibilityLabel(state.profileVisibilityKey.value),
                            showChevron: true,
                            onTap: () => sendAction(OpenProfileVisibility()),
                          )),
                      InfoRow(
                        icon: Icons.block_outlined,
                        label: 'settings_blocked_users'.tr,
                        showChevron: true,
                        onTap: () => sendAction(OpenBlockedUsers()),
                      ),
                      InfoRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'settings_change_password'.tr,
                        showChevron: true,
                        onTap: () => sendAction(OpenChangePassword()),
                      ),
                    ], padHorizontal: false),
                    SizedBox(height: 20.dp),
                    DangerButton(
                      text: 'settings_logout'.tr,
                      startIcon: Icon(Icons.logout_rounded, size: 18.dp, color: kListenRed),
                      onTap: () => sendAction(SettingsLogoutRequested()),
                    ),
                    SizedBox(height: 12.dp),
                    DangerButton(
                      text: 'settings_delete_account'.tr,
                      startIcon: Icon(Icons.delete_forever_outlined, size: 18.dp, color: kListenRed),
                      onTap: () => sendAction(SettingsDeleteAccountRequested()),
                    ),
                    SizedBox(height: 8.dp),
                    Text(
                      'settings_delete_account_hint'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                    ),
                    SizedBox(height: 14.dp),
                    Text(
                      'settings_app_version'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppLanguage(
    BuildContext context,
    SettingsState state,
    void Function(MyAction) sendAction,
  ) async {
    final picked = await showLanguageBottomSheet(
      context,
      title: 'settings_app_language'.tr,
      desc: 'settings_app_language_desc'.tr,
      selectedKey: state.currentLanguageKey.value,
    );
    if (picked != null) sendAction(SelectAppLanguage(picked));
  }

  Widget _sectionLabel(AppColors c, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: c.textFaint, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.6),
    );
  }

  /// [padHorizontal] — `InfoRow` o'z ichida 16dp gorizontal padding beradi
  /// (ripple to'liq kenglikda chizilishi uchun), shuning uchun faqat
  /// `InfoRow`lardan iborat kartalarda `false` beriladi.
  Widget _card(AppColors c, List<Widget> children, {bool divide = true, bool padHorizontal = true}) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (divide && i != children.length - 1) {
        items.add(Divider(height: 1.dp, thickness: 1.dp, color: c.outline));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(
        horizontal: padHorizontal ? 16.dp : 0,
        vertical: divide ? 0 : 14.dp,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.outline),
      ),
      child: Column(children: items),
    );
  }
}
