import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/core/mappers.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gender_selector.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/textfields/app_picker_field.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/textfields/birth_date_field.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'profile_edit_action.dart';
import 'profile_edit_state.dart';

/// S19 — Profil tahrirlash. Ism, tug'ilgan sana, davlat, jins, email va
/// avatar tahrirlanadi.
class ProfileEditContent extends ScreenContent<ProfileEditState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _birthCtrl;
  Worker? _formWorker;
  bool _hydrateBound = false;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _birthCtrl = TextEditingController();
  }

  void _bindHydrate(ProfileEditState state) {
    if (_hydrateBound) return;
    _hydrateBound = true;
    void apply() {
      final acc = state.account.value;
      _nameCtrl.text = acc?.name ?? '';
      _emailCtrl.text = acc?.email ?? '';
      final bd = state.birthDate.value;
      _birthCtrl.text = bd == null ? '' : formatDateDots(bd);
    }

    _formWorker = ever(state.formEpoch, (_) => apply());
    apply();
  }

  @override
  void onClose() {
    _formWorker?.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _birthCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, ProfileEditState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final now = DateTime.now();
    _bindHydrate(state);

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
              child: KeyboardAwareScrollView(
                padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 24.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Obx(
                        () {
                          final _ = state.avatarEpoch.value;
                          final account = state.account.value;
                          return ProfileAvatar(
                            initial: account?.initial ?? '',
                            gradient: account?.avatarGradient ?? avatarTealGradient,
                            imageUrl: account?.avatarUrl,
                            shape: ProfileAvatarShape.circle,
                            onEdit: () => sendAction(ChangeProfilePhoto()),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => sendAction(ChangeProfilePhoto()),
                          borderRadius: BorderRadius.circular(8.dp),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.dp,
                              vertical: 4.dp,
                            ),
                            child: Text(
                              'profile_edit_change_photo'.tr,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
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
                    Obx(() => BirthDateField(
                          controller: _birthCtrl,
                          date: state.birthDate.value,
                          firstDate: DateTime(1920),
                          lastDate: now,
                          onChanged: (d) => sendAction(SelectProfileBirthDate(d)),
                        )),
                    SizedBox(height: 16.dp),
                    Obx(() {
                      final code = state.country.value;
                      return AppPickerField(
                        label: 'country'.tr,
                        hint: 'O‘zbekiston',
                        icon: Icons.keyboard_arrow_down_rounded,
                        value: code.isEmpty ? null : formatCountryName(code),
                        onTap: () => _pickCountry(context, state, sendAction),
                      );
                    }),
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
                    IgnorePointer(
                      child: Opacity(
                        opacity: 0.65,
                        child: AppTextField(
                          label: 'email'.tr,
                          hint: 'dilnoza@email.com',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'profile_email_readonly_hint'.tr,
                      style: TextStyle(
                        color: c.textFaint,
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
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

  Future<void> _pickCountry(
    BuildContext context,
    ProfileEditState state,
    void Function(MyAction) sendAction,
  ) async {
    final picked = await showCountryPickerBottomSheet(
      context,
      title: 'country_picker_title'.tr,
      desc: 'country_picker_desc'.tr,
      selectedCode: state.country.value,
    );
    if (picked != null) sendAction(SelectProfileCountry(picked.code));
  }
}
