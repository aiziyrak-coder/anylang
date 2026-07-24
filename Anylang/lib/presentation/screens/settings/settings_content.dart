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
import 'settings_payload.dart';
import 'settings_state.dart';

/// Sozlamalar — [SettingsFocus.app] (dastur) yoki [SettingsFocus.account] (akkaunt).
class SettingsContent extends ScreenContent<SettingsState> {
  String _visibilityLabel(String key) => 'settings_visibility_$key'.tr;

  @override
  Widget build(BuildContext context, SettingsState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final focus = state.focus.value;
    final title = focus == SettingsFocus.app
        ? 'settings_app_title'.tr
        : 'settings_account_title'.tr;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(title: title, onBack: () => sendAction(Back())),
            ),
            Expanded(
              child: Obx(() {
                final f = state.focus.value;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 24.dp),
                  child: f == SettingsFocus.app
                      ? _appBody(context, c, state, sendAction)
                      : _accountBody(c, state, sendAction),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBody(
    BuildContext context,
    AppColors c,
    SettingsState state,
    void Function(MyAction) sendAction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(
          c,
          icon: Icons.tune_rounded,
          title: 'settings_app_title'.tr,
          subtitle: 'settings_app_desc'.tr,
        ),
        SizedBox(height: 20.dp),
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
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
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
                onChanged: (v) =>
                    sendAction(ToggleNotification('friend_requests', v)),
              )),
          Obx(() => ToggleRow(
                label: 'settings_notif_marketing'.tr,
                value: state.marketingEnabled.value,
                onChanged: (v) => sendAction(ToggleNotification('marketing', v)),
              )),
        ]),
        SizedBox(height: 20.dp),
        Text(
          'settings_app_version'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textFaint, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _accountBody(
    AppColors c,
    SettingsState state,
    void Function(MyAction) sendAction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(
          c,
          icon: Icons.manage_accounts_rounded,
          title: 'settings_account_title'.tr,
          subtitle: 'settings_account_desc'.tr,
        ),
        SizedBox(height: 20.dp),
        _sectionLabel(c, 'settings_account_profile'.tr),
        SizedBox(height: 9.dp),
        _card(c, [
          InfoRow(
            icon: Icons.edit_outlined,
            label: 'profile_edit'.tr,
            showChevron: true,
            onTap: () => sendAction(OpenEditProfileFromSettings()),
          ),
          InfoRow(
            icon: Icons.dialpad_rounded,
            label: 'numbers_title'.tr,
            showChevron: true,
            onTap: () => sendAction(OpenNumbersFromSettings()),
          ),
          InfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'profile_plans'.tr,
            showChevron: true,
            onTap: () => sendAction(OpenSubscriptionFromSettings()),
          ),
        ], padHorizontal: false),
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
        _sectionLabel(c, 'settings_account_danger'.tr),
        SizedBox(height: 9.dp),
        DangerButton(
          text: 'settings_logout'.tr,
          startIcon: Icon(Icons.logout_rounded, size: 18.dp, color: kListenRed),
          onTap: () => sendAction(SettingsLogoutRequested()),
        ),
        SizedBox(height: 12.dp),
        DangerButton(
          text: 'settings_delete_account'.tr,
          startIcon:
              Icon(Icons.delete_forever_outlined, size: 18.dp, color: kListenRed),
          onTap: () => sendAction(SettingsDeleteAccountRequested()),
        ),
        SizedBox(height: 8.dp),
        Text(
          'settings_delete_account_hint'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textFaint, fontSize: 12.sp, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _intro(
    AppColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16.dp),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(20.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
        boxShadow: c.glassShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.dp,
            height: 44.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(14.dp),
            ),
            child: Icon(icon, color: c.accentText, size: 22.dp),
          ),
          SizedBox(width: 12.dp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.dp),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _card(
    AppColors c,
    List<Widget> children, {
    bool divide = true,
    bool padHorizontal = true,
  }) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (divide && i != children.length - 1) {
        items.add(Divider(height: 1.dp, thickness: 0.5, color: c.outline));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(
        horizontal: padHorizontal ? 16.dp : 0,
        vertical: divide ? 0 : 14.dp,
      ),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
        boxShadow: c.glassShadow,
      ),
      child: Column(children: items),
    );
  }
}
