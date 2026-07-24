import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/permissions/app_permissions.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../login/login_screen.dart';
import 'onboarding_action.dart';
import 'onboarding_content.dart';
import 'onboarding_state.dart';

class OnboardingScreen extends Screen<OnboardingState, void> {
  OnboardingScreen()
      : super(
          mobileContent: OnboardingContent(),
        );

  Future<bool> _ensurePermissions(OnboardingState state) async {
    if (state.requestingPermissions.value) return false;
    state.requestingPermissions.value = true;
    try {
      final ok = await AppPermissions.requestAllRequired();
      if (ok) return true;
      final goSettings = await Get.dialog<bool>(
            AlertDialog(
              title: Text('onb4_denied_title'.tr),
              content: Text('onb4_denied_body'.tr),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('cancel'.tr),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  child: Text('onb4_open_settings'.tr),
                ),
              ],
            ),
          ) ??
          false;
      if (goSettings) {
        await AppPermissions.openAppSettingsIfNeeded();
      }
      return AppPermissions.allGranted();
    } finally {
      state.requestingPermissions.value = false;
    }
  }

  @override
  Future<void> actionHandler(OnboardingState state, MyAction action) async {
    switch (action) {
      case PageChanged a:
        state.currentPage.value = a.index;
      case SkipOnboarding _:
        final ok = await _ensurePermissions(state);
        if (ok) navigate(LoginScreen());
      case Continue _:
        final ok = await _ensurePermissions(state);
        if (ok) navigate(LoginScreen());
    }
  }
}
