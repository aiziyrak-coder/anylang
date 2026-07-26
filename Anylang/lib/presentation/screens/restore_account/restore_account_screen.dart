import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/network/auth_repository.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';

class RestoreAccountAction extends MyAction {}

class RestoreSubmit extends RestoreAccountAction {
  final String email;
  final String number;
  final String reason;
  RestoreSubmit(this.email, this.number, this.reason);
}

class RestoreBack extends RestoreAccountAction {}

class RestoreAccountState extends GetxController {
  RxBool isLoading = false.obs;
  RxString prefillEmail = ''.obs;
}

class RestoreAccountContent extends ScreenContent<RestoreAccountState> {
  late final TextEditingController emailCtrl;
  late final TextEditingController numberCtrl;
  late final TextEditingController reasonCtrl;

  @override
  void initContent() {
    emailCtrl = TextEditingController();
    numberCtrl = TextEditingController();
    reasonCtrl = TextEditingController();
  }

  @override
  void uiBuildFinished(RestoreAccountState state) {
    if (emailCtrl.text.isEmpty && state.prefillEmail.value.isNotEmpty) {
      emailCtrl.text = state.prefillEmail.value;
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    numberCtrl.dispose();
    reasonCtrl.dispose();
  }

  @override
  Widget build(
    BuildContext context,
    RestoreAccountState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: KeyboardAwareScrollView(
          padding: EdgeInsets.fromLTRB(24.dp, 16.dp, 24.dp, 24.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'nav_back'.tr,
                  onPressed: () => sendAction(RestoreBack()),
                  icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary),
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                'restore_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                'restore_subtitle'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 28.dp),
              AppTextField(
                label: 'email'.tr,
                hint: 'email_hint'.tr,
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16.dp),
              AppTextField(
                label: 'restore_number_optional'.tr,
                hint: 'restore_number_hint'.tr,
                controller: numberCtrl,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.dp),
              AppTextField(
                label: 'restore_reason'.tr,
                hint: 'restore_reason_hint'.tr,
                controller: reasonCtrl,
                maxLength: 500,
                maxLines: 4,
                minLines: 3,
              ),
              SizedBox(height: 24.dp),
              Obx(
                () => PrimaryButton(
                  text: 'restore_submit'.tr,
                  isLoading: state.isLoading.value,
                  onTap: () => sendAction(
                    RestoreSubmit(
                      emailCtrl.text,
                      numberCtrl.text,
                      reasonCtrl.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RestoreAccountScreen extends Screen<RestoreAccountState, String?> {
  RestoreAccountScreen() : super(mobileContent: RestoreAccountContent());

  @override
  void initState(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      state.prefillEmail.value = payload;
    }
  }

  @override
  Future<void> actionHandler(RestoreAccountState state, MyAction action) async {
    switch (action) {
      case RestoreBack _:
        popBackNavigate();
      case RestoreSubmit a:
        if (state.isLoading.value) return;
        final email = a.email.trim().toLowerCase();
        final emailErr = AuthValidators.emailError(email);
        if (emailErr != null) {
          showAppError(emailErr);
          return;
        }
        final number = a.number.trim();
        if (number.isNotEmpty &&
            (number.length != 7 || int.tryParse(number) == null)) {
          showAppError('restore_number_invalid'.tr);
          return;
        }
        if (a.reason.trim().length < 5) {
          showAppError('restore_reason_short'.tr);
          return;
        }
        state.isLoading.value = true;
        try {
          final repo = Get.find<AuthRepository>();
          final result = await repo.submitRestoreRequest(
            email: email,
            number: number.isEmpty ? null : number,
            reason: a.reason.trim(),
          );
          result.when(
            success: (_) {
              showAppMessage('restore_submitted'.tr);
              popBackNavigate();
            },
            failure: showAppError,
          );
        } catch (e) {
          showAppError(AuthValidators.safeError(e));
        } finally {
          state.isLoading.value = false;
        }
    }
  }
}
