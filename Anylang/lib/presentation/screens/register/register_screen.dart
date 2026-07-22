import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/auth_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../verify/verify_payload.dart';
import '../verify/verify_screen.dart';
import 'register_action.dart';
import 'register_content.dart';
import 'register_state.dart';

class RegisterScreen extends Screen<RegisterState, void> {
  RegisterScreen() : super(mobileContent: RegisterContent());

  @override
  void initState(void payload) {
    // Default: O‘zbekiston — foydalanuvchi tanlamasa ham register ishlaydi.
    if (state.countryCode.value.isEmpty) {
      state.countryCode.value = 'UZ';
      state.country.value = 'O‘zbekiston';
    }
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Future<void> actionHandler(RegisterState state, MyAction action) async {
    switch (action) {
      case SelectGender a:
        state.gender.value = a.gender;
      case SelectBirthDate a:
        state.birthDate.value = a.date;
      case SelectCountry a:
        state.country.value = a.name;
        state.countryCode.value = a.code.toUpperCase();
      case ToggleTerms a:
        state.termsAccepted.value = a.value;
      case RegisterSubmit a:
        final name = a.fullName.trim();
        final email = a.email.trim();
        final password = a.password;
        if (!state.termsAccepted.value) {
          showAppError('terms_required'.tr);
          return;
        }
        if (name.length < 2) {
          showAppError('full_name_required'.tr);
          return;
        }
        if (state.birthDate.value == null) {
          showAppError('birth_required'.tr);
          return;
        }
        if (state.countryCode.value.isEmpty) {
          showAppError('country_required'.tr);
          return;
        }
        if (!email.contains('@') || !email.contains('.')) {
          showAppError('email_invalid'.tr);
          return;
        }
        if (password.length < 8) {
          showAppError('password_short'.tr);
          return;
        }
        final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
        final hasDigit = RegExp(r'\d').hasMatch(password);
        if (!hasLetter || !hasDigit) {
          showAppError('password_weak'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.register(
            fullName: name,
            email: email,
            password: password,
            birthDate: _fmtDate(state.birthDate.value!),
            gender: state.gender.value,
            country: state.countryCode.value,
            termsAccepted: true,
          );
          await result.when(
            success: (data) async {
              final map = asMap(data);
              final otp = map?['debug_otp']?.toString();
              if (otp != null && otp.isNotEmpty) {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: Text('verify_title'.tr),
                    content: Text(
                      'register_otp_dialog'.trParams({'code': otp}),
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('continue'.tr),
                      ),
                    ],
                  ),
                );
              } else {
                showAppMessage('code_sent'.tr);
              }
              navigate(
                VerifyScreen(),
                payload: VerifyPayload(
                  email: email.toLowerCase(),
                  debugOtp: otp,
                ),
              );
            },
            failure: (err) {
              showAppError(err);
            },
          );
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
