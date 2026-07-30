import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/network/auth_repository.dart';
import '../../data/network/google_auth_service.dart';
import '../ui/my_snackbar.dart';
import 'app_snackbar.dart';
import 'auth_validators.dart';

/// Login / Register uchun umumiy Google Sign-In oqimi.
///
/// Muvaffaqiyatda `onSuccess`, verify kerak bo‘lsa `onNeedVerify(email)`.
Future<void> runGoogleSignInFlow({
  required Future<void> Function() onSuccess,
  required void Function(String email) onNeedVerify,
  void Function(String message)? onError,
}) async {
  void fail(String message) {
    if (onError != null) {
      onError(message);
    } else {
      showAppError(message);
    }
  }

  if (GoogleAuthService.serverClientId.isEmpty && !kDebugMode) {
    fail('google_coming_soon'.tr);
    return;
  }

  try {
    final idToken = await Get.find<GoogleAuthService>().signInForIdToken();
    if (idToken == null || idToken.isEmpty) {
      showAppMessage('google_cancelled'.tr);
      return;
    }

    final repo = Get.find<AuthRepository>();
    final outcome = await repo.loginWithGoogleDetailed(idToken: idToken);
    final body = outcome.body;
    final code = body?['error_code']?.toString();

    if (code == 'ACCOUNT_NOT_VERIFIED') {
      final email = (body?['email']?.toString() ?? '').trim();
      if (email.isEmpty) {
        fail('verify_email_missing'.tr);
        return;
      }
      showAppMessage('verify_required'.tr);
      onNeedVerify(email.toLowerCase());
      return;
    }
    if (code == 'ACCOUNT_EXISTS_PASSWORD') {
      fail('google_account_exists_password'.tr);
      return;
    }
    if (code == 'ACCOUNT_DELETED') {
      fail('google_account_deleted'.tr);
      return;
    }
    if (code == 'GOOGLE_ACCOUNT_CONFLICT') {
      fail('google_account_conflict'.tr);
      return;
    }

    await outcome.result.when(
      success: (_) async {
        MySnackBar.dismiss();
        await onSuccess();
      },
      failure: (err) async {
        final fromErr = AuthValidators.apiErrorCode(err);
        if (fromErr == 'ACCOUNT_EXISTS_PASSWORD') {
          fail('google_account_exists_password'.tr);
          return;
        }
        if (fromErr == 'ACCOUNT_DELETED') {
          fail('google_account_deleted'.tr);
          return;
        }
        if (fromErr == 'GOOGLE_ACCOUNT_CONFLICT') {
          fail('google_account_conflict'.tr);
          return;
        }
        fail(AuthValidators.safeError(err, fallbackKey: 'google_failed'));
      },
    );
  } catch (e) {
    fail(AuthValidators.safeError(e, fallbackKey: 'google_failed'));
  }
}
