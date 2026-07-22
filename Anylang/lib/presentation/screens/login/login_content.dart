import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/labeled_divider.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'login_action.dart';
import 'login_state.dart';

class LoginContent extends ScreenContent<LoginState> {

  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;

  @override
  void initContent() {
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, LoginState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: KeyboardAwareScrollView(
          padding: EdgeInsets.fromLTRB(24.dp, 24.dp, 24.dp, 12.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo tile
              Center(
                child: Image.asset('assets/images/logo.png', width: 66.dp, height: 66.dp),
              ),
              SizedBox(height: 20.dp),
              Text(
                'welcome'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textPrimary, fontSize: 26.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6.dp),
              Text(
                'login_subtitle'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 30.dp),
              AppTextField(
                label: 'email'.tr,
                hint: 'email_hint'.tr,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 18.dp),
              AppTextField(
                label: 'password'.tr,
                hint: '••••••••',
                controller: _passCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 12.dp),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => sendAction(ForgotPassword()),
                  borderRadius: BorderRadius.circular(8.dp),
                  child: Padding(
                    padding: EdgeInsets.all(4.dp),
                    child: Text(
                      'forgot_password'.tr,
                      style: TextStyle(color: c.accent, fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => sendAction(GoToRestoreAccount()),
                  borderRadius: BorderRadius.circular(8.dp),
                  child: Padding(
                    padding: EdgeInsets.all(4.dp),
                    child: Text(
                      'restore_account_link'.tr,
                      style: TextStyle(color: c.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Obx(() => PrimaryButton(
                    text: 'login'.tr,
                    isLoading: state.isLoading.value,
                    enabled: !state.isGoogleLoading.value,
                    onTap: () => sendAction(
                      LoginSubmit(_emailCtrl.text, _passCtrl.text),
                    ),
                  )),
              SizedBox(height: 22.dp),
              LabeledDivider(label: 'or'.tr),
              SizedBox(height: 22.dp),
              Obx(() => RichButton(
                    text: 'google_coming_soon'.tr,
                    isLoading: state.isGoogleLoading.value,
                    enabled: !state.isLoading.value,
                    onTap: () => sendAction(GoogleLogin()),
                    iconNearText: true,
                    startIcon: Image.asset('assets/images/ic_google.png', width: 20.dp, height: 20.dp),
                    textColor: c.textSecondary,
                    textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    padding: EdgeInsets.symmetric(vertical: 16.dp, horizontal: 16.dp),
                    borderRadius: BorderRadius.all(Radius.circular(18.dp)),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(18.dp),
                      border: Border.all(color: c.surfaceBorder),
                    ),
                  )),
              SizedBox(height: 20.dp),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no_account'.tr,
                    style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                  ),
                  InkWell(
                    onTap: () => sendAction(GoToRegister()),
                    borderRadius: BorderRadius.circular(8.dp),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.dp, vertical: 2.dp),
                      child: Text(
                        'register_action'.tr,
                        style: TextStyle(color: c.accent, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
