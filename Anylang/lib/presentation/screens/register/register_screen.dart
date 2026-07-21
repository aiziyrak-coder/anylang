import 'package:get/get.dart';

import '../../../data/network/auth_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../verify/verify_screen.dart';
import 'register_action.dart';
import 'register_content.dart';
import 'register_state.dart';

class RegisterScreen extends Screen<RegisterState, void> {
  RegisterScreen() : super(mobileContent: RegisterContent());

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
        state.countryCode.value = a.code;
      case ToggleTerms a:
        state.termsAccepted.value = a.value;
      case RegisterSubmit a:
        if (!state.termsAccepted.value) {
          showAppError('terms_required'.tr);
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
        if (!a.email.contains('@')) {
          showAppError('email_invalid'.tr);
          return;
        }
        if (a.password.length < 8) {
          showAppError('password_short'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.register(
            fullName: a.fullName,
            email: a.email,
            password: a.password,
            birthDate: _fmtDate(state.birthDate.value!),
            gender: state.gender.value,
            country: state.countryCode.value,
            termsAccepted: true,
          );
          result.when(
            success: (_) {
              showAppMessage('code_sent'.tr);
              navigate(VerifyScreen(), payload: a.email.trim().toLowerCase());
            },
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
