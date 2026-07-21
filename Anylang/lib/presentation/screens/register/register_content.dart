import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gender_selector.dart';
import '../../ui/gradient_background.dart';
import '../../ui/textfields/app_picker_field.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'country_picker_bottom_sheet.dart';
import 'register_action.dart';
import 'register_state.dart';

class RegisterContent extends ScreenContent<RegisterState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, RegisterState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.dp, 20.dp, 24.dp, 24.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'register_title'.tr,
                style: TextStyle(color: c.textPrimary, fontSize: 28.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4.dp),
              Text(
                'register_subtitle'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 22.dp),
              AppTextField(
                label: 'full_name'.tr,
                hint: 'full_name_hint'.tr,
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
              ),
              SizedBox(height: 16.dp),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Obx(() => AppPickerField(
                          label: 'birth_date'.tr,
                          hint: '14.03.1998',
                          icon: Icons.calendar_today_outlined,
                          value: state.birthDate.value == null ? null : formatDateDots(state.birthDate.value!),
                          onTap: () => _pickDate(context, state, sendAction),
                        )),
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    child: Obx(() => AppPickerField(
                          label: 'country'.tr,
                          hint: 'O‘zbekiston',
                          icon: Icons.keyboard_arrow_down_rounded,
                          value: state.country.value.isEmpty ? null : state.country.value,
                          onTap: () => _pickCountry(context, sendAction),
                        )),
                  ),
                ],
              ),
              SizedBox(height: 16.dp),
              Text(
                'gender'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8.dp),
              Obx(() => GenderSelector(
                    value: state.gender.value,
                    onSelect: (g) => sendAction(SelectGender(g)),
                  )),
              SizedBox(height: 16.dp),
              AppTextField(
                label: 'email'.tr,
                hint: 'email_hint'.tr,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16.dp),
              AppTextField(
                label: 'password'.tr,
                hint: '••••••••',
                controller: _passCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 18.dp),
              _terms(context, state, sendAction),
              SizedBox(height: 22.dp),
              Obx(() => PrimaryButton(
                    text: 'register_title'.tr,
                    isLoading: state.isLoading.value,
                    enabled: state.termsAccepted.value,
                    onTap: () => sendAction(
                      RegisterSubmit(_nameCtrl.text, _emailCtrl.text, _passCtrl.text),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _terms(BuildContext context, RegisterState state, void Function(MyAction) sendAction) {
    final c = context.appColors;
    return Obx(() {
      final checked = state.termsAccepted.value;
      return InkWell(
        onTap: () => sendAction(ToggleTerms(!checked)),
        borderRadius: BorderRadius.circular(8.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24.dp,
              height: 24.dp,
              decoration: BoxDecoration(
                color: checked ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(7.dp),
                border: Border.all(color: checked ? c.accent : c.surfaceBorder, width: 1.6),
              ),
              child: checked ? Icon(Icons.check, size: 16.dp, color: c.onAccent) : null,
            ),
            SizedBox(width: 12.dp),
            Expanded(
              child: Text(
                'terms_agree'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp, height: 1.35),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickDate(BuildContext context, RegisterState state, void Function(MyAction) sendAction) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.birthDate.value ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) sendAction(SelectBirthDate(picked));
  }

  Future<void> _pickCountry(BuildContext context, void Function(MyAction) sendAction) async {
    final picked = await showCountryPickerBottomSheet(context);
    if (picked != null) sendAction(SelectCountry(picked.name, picked.code));
  }
}
