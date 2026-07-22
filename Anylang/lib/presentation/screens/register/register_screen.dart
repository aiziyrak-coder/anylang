import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../main/main_screen.dart';
import '../verify/verify_payload.dart';
import '../verify/verify_screen.dart';
import 'register_action.dart';
import 'register_content.dart';
import 'register_state.dart';

class RegisterScreen extends Screen<RegisterState, void> {
  RegisterScreen() : super(mobileContent: RegisterContent());

  @override
  void initState(void payload) {
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
        await _submit(state, a);
    }
  }

  Future<void> _submit(RegisterState state, RegisterSubmit a) async {
    final name = a.fullName.trim();
    final email = a.email.trim().toLowerCase();
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
    final ageYears =
        DateTime.now().difference(state.birthDate.value!).inDays / 365.25;
    if (ageYears < 13) {
      showAppError('birth_too_young'.tr);
      return;
    }
    final country = state.countryCode.value.trim().toUpperCase();
    if (country.length != 2) {
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
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
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
        country: country,
        termsAccepted: true,
      );

      final data = result.dataOrNull;
      if (data == null) {
        showAppError(result.errorOrNull ?? 'error'.tr);
        return;
      }

      final map = asMap(data);
      final otp = map?['debug_otp']?.toString().trim();

      // SMTP yo‘q: OTP bilan darhol verify → asosiy ekran.
      if (otp != null && otp.length == 6) {
        final verified = await repo.verifyEmail(email: email, code: otp);
        if (verified.dataOrNull != null) {
          showAppMessage('register_done'.tr);
          await connectRealtimeIfNeeded();
          navigateAndRemoveUntil(MainScreen());
          return;
        }
        showAppError(verified.errorOrNull);
        navigate(
          VerifyScreen(),
          payload: VerifyPayload(email: email, debugOtp: otp),
        );
        return;
      }

      showAppMessage('code_sent'.tr);
      navigate(
        VerifyScreen(),
        payload: VerifyPayload(email: email, debugOtp: otp),
      );
    } finally {
      state.isLoading.value = false;
    }
  }
}
