import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gender_selector.dart';
import '../../ui/gradient_background.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/textfields/app_picker_field.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import '../register/country_picker_bottom_sheet.dart';
import 'profile_edit_action.dart';
import 'profile_edit_state.dart';

/// S19 — Profil tahrirlash. Ism, tug'ilgan sana, davlat, jins, email va
/// avatar tahrirlanadi.
class ProfileEditContent extends ScreenContent<ProfileEditState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
  }

  @override
  void uiBuildFinished(ProfileEditState state) {
    _nameCtrl.text = state.account?.name ?? '';
    // TODO: email hali ProfileAccount modelida yo'q — mock.
    _emailCtrl.text = 'dilnoza@email.com';
  }

  @override
  void onClose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, ProfileEditState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final account = state.account;
    // resizeToAvoidBottomInset Screen yadrosida false — klaviatura ochilganda
    // pastdagi fieldlar/tugma ko'rinishi uchun scroll pastki paddingi shu
    // qadar oshiriladi (screen o'zi siljimaydi, faqat scroll maydoni kengayadi).
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'profile_edit_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 24.dp + keyboardInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ProfileAvatar(
                        initial: account?.initial ?? '',
                        gradient: account?.avatarGradient ?? avatarTealGradient,
                        shape: account?.isBusiness == true ? ProfileAvatarShape.roundedSquare : ProfileAvatarShape.circle,
                        onEdit: () => sendAction(ChangeProfilePhoto()),
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    Center(
                      child: InkWell(
                        onTap: () => sendAction(ChangeProfilePhoto()),
                        child: Text(
                          'profile_edit_change_photo'.tr,
                          style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                        ),
                      ),
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
                          onSelect: (g) => sendAction(SelectProfileGender(g)),
                        )),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'email'.tr,
                      hint: 'dilnoza@email.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 28.dp),
                    Obx(() => PrimaryButton(
                          text: 'profile_edit_save'.tr,
                          isLoading: state.isSaving.value,
                          onTap: () => _save(sendAction),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save(void Function(MyAction) sendAction) {
    sendAction(SaveProfileEdit(fullName: _nameCtrl.text, email: _emailCtrl.text));
  }

  Future<void> _pickDate(BuildContext context, ProfileEditState state, void Function(MyAction) sendAction) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.birthDate.value ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) sendAction(SelectProfileBirthDate(picked));
  }

  Future<void> _pickCountry(BuildContext context, void Function(MyAction) sendAction) async {
    final picked = await showCountryPickerBottomSheet(context);
    if (picked != null) sendAction(SelectProfileCountry(picked.name));
  }
}
