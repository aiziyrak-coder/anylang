import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/local/account_store.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../ui/my_snackbar.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/google_sign_in_flow.dart';
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
import 'login_payload.dart';
import 'login_state.dart';

class LoginScreen extends Screen<LoginState, LoginPayload?> {
  LoginScreen() : super(mobileContent: LoginContent());

  @override
  void initState(LoginPayload? payload) {
    state.isAddAccount.value = payload?.addAccount == true;
  }

  Future<void> _enterApp() async {
    try {
      await AccountStore.syncActiveFromSessionStore();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountStore sync failed: $e');
      }
    }
    await connectRealtimeIfNeeded();
    navigateAndRemoveUntil(MainScreen());
  }

  Future<void> _restoreParkedIfNeeded() async {
    final p = payload;
    if (p == null || !p.addAccount) return;
    final id = p.restoreUserId;
    if (id == null) return;
    final ok = await AccountStore.activate(id);
    if (ok) {
      await connectRealtimeIfNeeded();
      navigateAndRemoveUntil(MainScreen());
    }
  }

  @override
  Future<void> actionHandler(LoginState state, MyAction action) async {
    switch (action) {
      case Back _:
        if (payload?.addAccount == true) {
          await _restoreParkedIfNeeded();
          return;
        }
        popBackNavigate();
      case LoginSubmit a:
        if (state.isLoading.value || state.isGoogleLoading.value) return;
        state.email = a.email;
        final emailErr = AuthValidators.emailError(a.email);
        if (emailErr != null) {
          showAppError(emailErr);
          return;
        }
        final passErr = AuthValidators.loginPasswordError(a.password);
        if (passErr != null) {
          showAppError(passErr);
          return;
        }
        // Always authenticate against the server — never activate a saved
        // slot by email alone (password must be verified).
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
            navigate(
              RestoreAccountScreen(),
              payload: a.email.trim().toLowerCase(),
            );
            return;
          }

          await outcome.result.when(
            success: (_) async {
              state.password = '';
              MySnackBar.dismiss();
              await _enterApp();
            },
            failure: (err) async => showAppError(
              AuthValidators.safeError(err, fallbackKey: 'error_generic'),
            ),
          );
        } finally {
          state.isLoading.value = false;
        }
      case GoToRegister _:
        navigate(RegisterScreen());
      case GoogleLogin _:
        if (state.isLoading.value || state.isGoogleLoading.value) return;
        state.isGoogleLoading.value = true;
        try {
          await runGoogleSignInFlow(
            onSuccess: _enterApp,
            onNeedVerify: (email) {
              navigate(
                VerifyScreen(),
                payload: VerifyPayload(email: email),
              );
            },
          );
        } finally {
          state.isGoogleLoading.value = false;
        }
      case ForgotPassword _:
        navigate(ForgotPasswordScreen());
      case GoToRestoreAccount _:
        navigate(RestoreAccountScreen());
    }
  }
}
