import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/network/auth_repository.dart';
import '../../../data/network/google_auth_service.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../main/main_screen.dart';
import '../register/register_screen.dart';
import '../restore_account/restore_account_screen.dart';
import '../verify/verify_payload.dart';
import '../verify/verify_screen.dart';
import 'login_action.dart';
import 'login_content.dart';
import 'login_state.dart';

class LoginScreen extends Screen<LoginState, void> {
  LoginScreen() : super(mobileContent: LoginContent());

  bool _validEmail(String email) {
    final v = email.trim();
    return v.contains('@') && v.contains('.') && v.length >= 5;
  }

  @override
  Future<void> actionHandler(LoginState state, MyAction action) async {
    switch (action) {
      case LoginSubmit a:
        if (!_validEmail(a.email)) {
          showAppError('email_invalid'.tr);
          return;
        }
        if (a.password.trim().length < 8) {
          showAppError('password_short'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final outcome = await repo.loginDetailed(
            email: a.email,
            password: a.password,
          );

          final body = outcome.body;
          if (body != null && body['error_code'] == 'ACCOUNT_NOT_VERIFIED') {
            showAppMessage('verify_required'.tr);
            navigate(
              VerifyScreen(),
              payload: VerifyPayload(email: a.email.trim().toLowerCase()),
            );
            return;
          }

          if (body != null && body['error_code'] == 'ACCOUNT_DELETED') {
            showAppMessage('account_deleted_restore'.tr);
            navigate(RestoreAccountScreen(), payload: a.email.trim().toLowerCase());
            return;
          }

          outcome.result.when(
            success: (_) async {
              await connectRealtimeIfNeeded();
              navigateAndRemoveUntil(MainScreen());
            },
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
      case GoToRegister _:
        navigate(RegisterScreen());
      case GoogleLogin _:
        if (GoogleAuthService.serverClientId.isEmpty && !kDebugMode) {
          showAppMessage('google_coming_soon'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final idToken =
              await Get.find<GoogleAuthService>().signInForIdToken();
          if (idToken == null || idToken.isEmpty) return;
          final repo = Get.find<AuthRepository>();
          final outcome =
              await repo.loginWithGoogleDetailed(idToken: idToken);
          final body = outcome.body;
          if (body != null && body['error_code'] == 'ACCOUNT_NOT_VERIFIED') {
            showAppMessage('verify_required'.tr);
            navigate(
              VerifyScreen(),
              payload: VerifyPayload(
                email: body['email']?.toString() ?? '',
              ),
            );
            return;
          }
          outcome.result.when(
            success: (_) async {
              await connectRealtimeIfNeeded();
              navigateAndRemoveUntil(MainScreen());
            },
            failure: showAppError,
          );
        } catch (e) {
          showAppError(e.toString());
        } finally {
          state.isLoading.value = false;
        }
      case ForgotPassword _:
        navigate(ForgotPasswordScreen());
      case GoToRestoreAccount _:
        navigate(RestoreAccountScreen());
    }
  }
}
