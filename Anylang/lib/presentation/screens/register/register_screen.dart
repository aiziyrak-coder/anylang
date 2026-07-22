import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/countries_service.dart';
import '../../../domain/models/country_option.dart';
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
    state.formError.value = '';
    state.isLoading.value = false;
    if (state.countryCode.value.isEmpty) {
      _applyDefaultCountry();
    }
  }

  String? _deviceCountryCode() {
    final fromGet = Get.deviceLocale?.countryCode;
    if (fromGet != null && fromGet.length == 2) {
      return fromGet.toUpperCase();
    }
    try {
      final segments = Platform.localeName.split(RegExp(r'[_-]'));
      if (segments.length >= 2) {
        final tail = segments.last.toUpperCase();
        if (tail.length == 2) return tail;
      }
    } catch (_) {}
    return null;
  }

  void _applyDefaultCountry() {
    final code = _deviceCountryCode() ?? 'UZ';
    CountryOption picked;
    if (Get.isRegistered<CountriesService>()) {
      picked = Get.find<CountriesService>().findByCode(code) ??
          kFallbackCountries.firstWhere(
            (c) => c.code == code,
            orElse: () => kFallbackCountries.first,
          );
    } else {
      picked = kFallbackCountries.firstWhere(
        (c) => c.code == code,
        orElse: () => kFallbackCountries.first,
      );
    }
    state.countryCode.value = picked.code;
    state.country.value = picked.localizedName;
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _fail(String message) {
    state.formError.value = message;
    showAppError(message);
  }

  @override
  Future<void> actionHandler(RegisterState state, MyAction action) async {
    switch (action) {
      case SelectGender a:
        state.gender.value = a.gender;
        state.formError.value = '';
      case SelectBirthDate a:
        state.birthDate.value = a.date;
        state.formError.value = '';
      case SelectCountry a:
        state.country.value = a.name;
        state.countryCode.value = a.code.toUpperCase();
        state.formError.value = '';
      case ToggleTerms a:
        state.termsAccepted.value = a.value;
        state.formError.value = '';
      case RegisterSubmit a:
        await _submit(state, a);
    }
  }

  Future<void> _submit(RegisterState state, RegisterSubmit a) async {
    final name = a.fullName.trim();
    final email = a.email.trim().toLowerCase();
    final password = a.password;
    state.formError.value = '';

    if (!state.termsAccepted.value) {
      _fail('terms_required'.tr);
      return;
    }
    if (name.length < 2) {
      _fail('full_name_required'.tr);
      return;
    }
    if (state.birthDate.value == null) {
      _fail('birth_required'.tr);
      return;
    }
    final ageYears =
        DateTime.now().difference(state.birthDate.value!).inDays / 365.25;
    if (ageYears < 13) {
      _fail('birth_too_young'.tr);
      return;
    }
    final country = state.countryCode.value.trim().toUpperCase();
    if (country.length != 2) {
      _fail('country_required'.tr);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _fail('email_invalid'.tr);
      return;
    }
    if (password.length < 8) {
      _fail('password_short'.tr);
      return;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      _fail('password_weak'.tr);
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
        final err = result.errorOrNull?.toString() ?? 'error'.tr;
        _fail(err);
        return;
      }

      final map = asMap(data);
      final otp = map?['debug_otp']?.toString().trim();
      final serverMsg = map?['message']?.toString();

      // SMTP yo‘q / bootstrap: OTP bilan darhol verify → asosiy ekran.
      if (otp != null && otp.length == 6) {
        final verified = await repo.verifyEmail(email: email, code: otp);
        if (verified.dataOrNull != null) {
          showAppMessage('register_done'.tr);
          await connectRealtimeIfNeeded();
          _goHome();
          return;
        }
        final verifyErr = verified.errorOrNull?.toString();
        if (verifyErr != null && verifyErr.isNotEmpty) {
          _fail(verifyErr);
        }
        _goVerify(email, otp);
        return;
      }

      showAppMessage(serverMsg ?? 'code_sent'.tr);
      _goVerify(email, otp);
    } catch (e, st) {
      debugPrint('register submit error: $e\n$st');
      _fail(e.toString());
    } finally {
      state.isLoading.value = false;
    }
  }

  void _goHome() {
    try {
      navigateAndRemoveUntil(MainScreen());
    } catch (e) {
      debugPrint('navigate home failed: $e');
      Get.offAll(() => MainScreen().build());
    }
  }

  void _goVerify(String email, String? otp) {
    try {
      navigate(
        VerifyScreen(),
        payload: VerifyPayload(email: email, debugOtp: otp),
      );
    } catch (e) {
      debugPrint('navigate verify failed: $e');
      final screen = VerifyScreen();
      screen.payload = VerifyPayload(email: email, debugOtp: otp);
      Get.to(() => screen.build());
    }
  }
}
