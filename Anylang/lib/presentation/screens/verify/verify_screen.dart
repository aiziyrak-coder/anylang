import 'package:get/get.dart';

import '../../../data/network/auth_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../main/main_screen.dart';
import 'verify_action.dart';
import 'verify_content.dart';
import 'verify_state.dart';

class VerifyScreen extends Screen<VerifyState, String> {
  VerifyScreen() : super(mobileContent: VerifyContent());

  @override
  void initState(String? payload) {
    state.email.value = payload ?? '';
  }

  @override
  Future<void> actionHandler(VerifyState state, MyAction action) async {
    switch (action) {
      case CodeChanged a:
        state.code.value = a.code;
      case ResendCode _:
        if (state.email.value.isEmpty) return;
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.resendVerification(email: state.email.value);
          result.when(
            success: (_) => showAppMessage('code_sent'.tr),
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
      case VerifySubmit a:
        if (state.email.value.isEmpty) return;
        if (a.code.trim().length != 6) {
          showAppError('code_invalid'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.verifyEmail(
            email: state.email.value,
            code: a.code,
          );
          result.when(
            success: (_) async {
              await connectRealtimeIfNeeded();
              navigateAndRemoveUntil(MainScreen());
            },
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
