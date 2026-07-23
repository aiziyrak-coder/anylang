import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/core/mappers.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../modal/simple_list_picker_bottom_sheet.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/media_tile.dart';
import '../../ui/items/removable_chip.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/textfields/app_picker_field.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'edit_business_info_action.dart';
import 'edit_business_info_state.dart';

const List<String> kBusinessRoles = [
  'Ishlab chiqaruvchi',
  'Distributor',
  'Chakana savdo',
  'Xizmat ko‘rsatuvchi',
];

/// S17 — Biznes ma'lumot tahrirlash. Logotip, kompaniya ma'lumotlari,
/// sertifikatlar va zavod rasmlari tahrirlanadi.
class EditBusinessInfoContent extends ScreenContent<EditBusinessInfoState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _descriptionCtrl;
  Worker? _formWorker;
  int _lastEpoch = -1;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
  }

  void _bindHydrate(EditBusinessInfoState state) {
    _formWorker?.dispose();
    _formWorker = ever(state.formEpoch, (_) {
      _nameCtrl.text = state.companyName.value;
      _websiteCtrl.text = state.website.value;
      _descriptionCtrl.text = state.description.value;
      _lastEpoch = state.formEpoch.value;
    });
    if (state.formEpoch.value != _lastEpoch) {
      _nameCtrl.text = state.companyName.value;
      _websiteCtrl.text = state.website.value;
      _descriptionCtrl.text = state.description.value;
      _lastEpoch = state.formEpoch.value;
    }
  }

  @override
  void onClose() {
    _formWorker?.dispose();
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _descriptionCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, EditBusinessInfoState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    _bindHydrate(state);

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'business_edit_title'.tr,
                onBack: () => sendAction(Back()),
                trailing: Obx(() => InkWell(
                      onTap: state.isSaving.value ? null : () => _save(state, sendAction),
                      child: Text(
                        'business_save'.tr,
                        style: TextStyle(color: c.accentText, fontSize: 15.sp, fontWeight: FontWeight.w700),
                      ),
                    )),
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
                        () => ProfileAvatar(
                          initial: initialsOf(state.companyName.value.isNotEmpty
                              ? state.companyName.value
                              : 'A'),
                          gradient: avatarBrownGradient,
                          imageUrl: state.logoUrl.value,
                          shape: ProfileAvatarShape.roundedSquare,
                          onEdit: () => sendAction(ChangeLogo()),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    Center(
                      child: InkWell(
                        onTap: () => sendAction(ChangeLogo()),
                        child: Text(
                          'business_change_logo'.tr,
                          style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                        ),
                      ),
                    ),
                    SizedBox(height: 22.dp),
                    AppTextField(
                      label: 'business_company_name'.tr,
                      hint: 'business_company_name_hint'.tr,
                      controller: _nameCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Obx(() {
                            final code = state.country.value;
                            return AppPickerField(
                              label: 'country'.tr,
                              hint: 'country'.tr,
                              value: code.isEmpty ? null : formatCountryName(code),
                              icon: Icons.keyboard_arrow_down_rounded,
                              onTap: () => _pickCountry(context, state, sendAction),
                            );
                          }),
                        ),
                        SizedBox(width: 12.dp),
                        Expanded(
                          child: Obx(() => AppPickerField(
                                label: 'business_role'.tr,
                                hint: 'business_role'.tr,
                                value: state.role.value.isEmpty ? null : state.role.value,
                                icon: Icons.keyboard_arrow_down_rounded,
                                onTap: () => _pickRole(context, state, sendAction),
                              )),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_website'.tr,
                      hint: 'anadolucraft.com',
                      controller: _websiteCtrl,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_description'.tr,
                      hint: 'business_description_hint'.tr,
                      controller: _descriptionCtrl,
                      maxLines: 4,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    SizedBox(height: 20.dp),
                    Text(
                      'business_certificates'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            for (final cert in state.certificates)
                              RemovableChip(label: cert, onRemove: () => sendAction(RemoveCertificate(cert))),
                            RemovableChip.add(
                              label: 'business_add_certificate'.tr,
                              onTap: () => sendAction(AddCertificateRequested()),
                            ),
                          ],
                        )),
                    SizedBox(height: 20.dp),
                    Text(
                      'business_factory_images'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            for (final img in state.factoryImages)
                              MediaTile.image(
                                imageUrl: img.url,
                                gradient: prodOliveGradient,
                                onTap: () =>
                                    sendAction(OpenFactoryImage(img.url)),
                              ),
                            MediaTile.upload(
                              uploadLabel: 'business_upload'.tr,
                              onTap: () =>
                                  sendAction(AddFactoryImageRequested()),
                            ),
                          ],
                        )),
                    SizedBox(height: 28.dp),
                    Obx(() => PrimaryButton(
                          text: 'business_save'.tr,
                          isLoading: state.isSaving.value,
                          onTap: () => _save(state, sendAction),
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

  void _save(EditBusinessInfoState state, void Function(MyAction) sendAction) {
    sendAction(SaveBusinessInfo(
      companyName: _nameCtrl.text,
      website: _websiteCtrl.text,
      description: _descriptionCtrl.text,
    ));
  }

  Future<void> _pickCountry(
    BuildContext context,
    EditBusinessInfoState state,
    void Function(MyAction) sendAction,
  ) async {
    final picked = await showCountryPickerBottomSheet(
      context,
      title: 'country_picker_title'.tr,
      desc: 'country_picker_desc'.tr,
      selectedCode: state.country.value,
    );
    if (picked != null) sendAction(SelectBusinessCountry(picked.code));
  }

  Future<void> _pickRole(BuildContext context, EditBusinessInfoState state, void Function(MyAction) sendAction) async {
    final picked = await showSimpleListPickerBottomSheet(
      context,
      title: 'business_role'.tr,
      items: kBusinessRoles,
      selected: state.role.value,
    );
    if (picked != null) sendAction(SelectBusinessRole(picked));
  }
}
