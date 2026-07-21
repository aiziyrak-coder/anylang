import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/otp_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'verify_action.dart';
import 'verify_state.dart';

class VerifyContent extends ScreenContent<VerifyState> {

  Timer? _timer;
  static const int _resendSeconds = 59;

  @override
  void initContent() {
    _startTimer();
  }

  @override
  void onClose() {
    _timer?.cancel();
  }

  void _startTimer() {
    final state = Get.find<VerifyState>();
    state.secondsLeft.value = _resendSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.secondsLeft.value <= 0) {
        t.cancel();
      } else {
        state.secondsLeft.value--;
      }
    });
  }

  String _format(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, VerifyState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.dp, 40.dp, 24.dp, 24.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mail ikonka tile
              Center(
                child: Container(
                  padding: EdgeInsets.all(16.dp),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(20.dp),
                    border: Border.all(color: c.accent),
                  ),
                  child: Icon(Icons.mail_outline, color: c.accent, size: 30.dp),
                ),
              ),
              SizedBox(height: 22.dp),
              Text(
                'verify_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textPrimary, fontSize: 24.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.dp),
              Obx(() => Text(
                    'verify_subtitle'.trParams({'email': state.email.value}),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 14.sp, height: 1.4),
                  )),
              SizedBox(height: 28.dp),
              OtpField(
                length: 6,
                onChanged: (v) => sendAction(CodeChanged(v)),
              ),
              SizedBox(height: 24.dp),
              Obx(() => PrimaryButton(
                    text: 'verify_action'.tr,
                    isLoading: state.isLoading.value,
                    enabled: state.code.value.length == 6,
                    onTap: () => sendAction(VerifySubmit(state.code.value)),
                  )),
              SizedBox(height: 20.dp),
              _resend(context, state, sendAction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resend(BuildContext context, VerifyState state, void Function(MyAction) sendAction) {
    final c = context.appColors;
    return Obx(() {
      final left = state.secondsLeft.value;
      final canResend = left <= 0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'code_not_received'.tr,
            style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
          ),
          InkWell(
            onTap: canResend
                ? () {
                    _startTimer();
                    sendAction(ResendCode());
                  }
                : null,
            borderRadius: BorderRadius.circular(8.dp),
            child: Padding(
              padding: EdgeInsets.all(2.dp),
              child: Text(
                'resend'.tr,
                style: TextStyle(
                  color: canResend ? c.accent : c.textFaint,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!canResend)
            Text(
              ' — ${_format(left)}',
              style: TextStyle(color: c.textFaint, fontSize: 14.sp),
            ),
        ],
      );
    });
  }
}
