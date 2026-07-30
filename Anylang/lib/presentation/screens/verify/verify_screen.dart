import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../ui/my_snackbar.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../main/main_screen.dart';
import 'verify_action.dart';
import 'verify_content.dart';
import 'verify_payload.dart';
import 'verify_state.dart';

class VerifyScreen extends Screen<VerifyState, Object?> {
  VerifyScreen() : super(mobileContent: VerifyContent());

  @override
  void initState(Object? payload) {
    // Clear leftover GetX state from a previous visit.
    state.code.value = '';
    state.debugOtp.value = '';
    state.isLoading.value = false;
    state.secondsLeft.value = 0;
    state.resendSucceeded.value = false;

    if (payload is VerifyPayload) {
      state.email.value = payload.email;
      state.debugOtp.value = payload.debugOtp ?? '';
      if (payload.debugOtp != null && payload.debugOtp!.length == 6) {
        state.code.value = payload.debugOtp!;
      }
    } else if (payload is String) {
      state.email.value = payload;
    }
  }

  @override
  Future<void> actionHandler(VerifyState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case CodeChanged a:
        state.code.value = a.code;
      case ResendCode _:
        if (state.email.value.trim().isEmpty) {
          showAppError('email_required'.tr);
          return;
        }
        if (state.isLoading.value) return;
        state.isLoading.value = true;
        state.resendSucceeded.value = false;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.resendVerification(email: state.email.value);
          final data = result.dataOrNull;
          if (data == null) {
            showAppError(result.errorOrNull);
            return;
          }
          final map = asMap(data);
          final otp = map?['debug_otp']?.toString();
          if (kDebugMode && otp != null && otp.isNotEmpty) {
            state.debugOtp.value = otp;
            state.code.value = otp;
            showAppMessage('verify_debug_otp'.trParams({'otp': otp}));
          } else {
            showAppMessage('code_sent'.tr);
          }
          // Signal content to start the cooldown only after success.
          state.resendSucceeded.value = true;
        } finally {
          state.isLoading.value = false;
        }
      case VerifySubmit a:
        if (state.email.value.trim().isEmpty) {
          showAppError('email_required'.tr);
          return;
        }
        if (state.isLoading.value) return;
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
          await result.when(
            success: (_) async {
              MySnackBar.dismiss();
              await connectRealtimeIfNeeded();
              navigateAndRemoveUntil(MainScreen());
            },
            failure: (err) async => showAppError(err),
          );
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
