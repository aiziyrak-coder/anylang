import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/auth_repository.dart';
import '../login/login_screen.dart';

class ForgotPasswordAction extends MyAction {}

class ForgotSendCode extends ForgotPasswordAction {
  final String email;
  ForgotSendCode(this.email);
}

class ForgotReset extends ForgotPasswordAction {
  final String code;
  final String password;
  ForgotReset(this.code, this.password);
}

class ForgotBack extends ForgotPasswordAction {}

class ForgotPasswordState extends GetxController {
  RxBool isLoading = false.obs;
  RxInt step = 0.obs; // 0 email, 1 code+password
  RxString email = ''.obs;
}

class ForgotPasswordContent extends ScreenContent<ForgotPasswordState> {
  late final TextEditingController emailCtrl;
  late final TextEditingController codeCtrl;
  late final TextEditingController passCtrl;

  @override
  void initContent() {
    emailCtrl = TextEditingController();
    codeCtrl = TextEditingController();
    passCtrl = TextEditingController();
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    codeCtrl.dispose();
    passCtrl.dispose();
  }

  @override
  Widget build(
    BuildContext context,
    ForgotPasswordState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: KeyboardAwareScrollView(
          padding: EdgeInsets.fromLTRB(24.dp, 16.dp, 24.dp, 24.dp),
          child: Obx(() {
            final step = state.step.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => sendAction(ForgotBack()),
                    icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary),
                  ),
                ),
                SizedBox(height: 8.dp),
                Text(
                  'forgot_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.dp),
                Text(
                  step == 0 ? 'forgot_subtitle_email'.tr : 'forgot_subtitle_code'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                ),
                SizedBox(height: 28.dp),
                if (step == 0) ...[
                  AppTextField(
                    label: 'email'.tr,
                    hint: 'email_hint'.tr,
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 24.dp),
                  PrimaryButton(
                    text: 'send_code'.tr,
                    isLoading: state.isLoading.value,
                    onTap: () => sendAction(ForgotSendCode(emailCtrl.text)),
                  ),
                ] else ...[
                  AppTextField(
                    label: 'verify_code'.tr,
                    hint: '000000',
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16.dp),
                  AppTextField(
                    label: 'new_password'.tr,
                    hint: '••••••••',
                    controller: passCtrl,
                    isPassword: true,
                  ),
                  SizedBox(height: 24.dp),
                  PrimaryButton(
                    text: 'reset_password'.tr,
                    isLoading: state.isLoading.value,
                    onTap: () => sendAction(
                      ForgotReset(codeCtrl.text, passCtrl.text),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends Screen<ForgotPasswordState, void> {
  ForgotPasswordScreen() : super(mobileContent: ForgotPasswordContent());

  @override
  Future<void> actionHandler(
    ForgotPasswordState state,
    MyAction action,
  ) async {
    switch (action) {
      case ForgotBack _:
        if (state.step.value == 1) {
          state.step.value = 0;
        } else {
          popBackNavigate();
        }
      case ForgotSendCode a:
        final email = a.email.trim().toLowerCase();
        if (!email.contains('@')) {
          showAppError('email_invalid'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final result =
              await Get.find<AuthRepository>().forgotPassword(email: email);
          result.when(
            success: (_) {
              state.email.value = email;
              state.step.value = 1;
              showAppMessage('code_sent'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
      case ForgotReset a:
        if (a.code.trim().length != 6) {
          showAppError('code_invalid'.tr);
          return;
        }
        if (a.password.length < 8) {
          showAppError('password_short'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final result = await Get.find<AuthRepository>().resetPassword(
            email: state.email.value,
            code: a.code.trim(),
            newPassword: a.password,
          );
          result.when(
            success: (_) {
              showAppMessage('password_reset_ok'.tr);
              // Sozlamalardan kelgan bo'lsa — sessiyani saqlab qaytamiz.
              if (SessionStore.hasSession) {
                popBackNavigate();
              } else {
                navigateAndRemoveUntil(LoginScreen());
              }
            },
            failure: showAppError,
          );
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
