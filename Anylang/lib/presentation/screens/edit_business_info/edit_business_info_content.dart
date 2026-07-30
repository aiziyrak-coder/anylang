import 'dart:async';

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

const List<String> kBusinessRoleCodes = [
  'manufacturer',
  'distributor',
  'retail',
  'service',
];

const List<String> kIncotermCodes = [
  'EXW',
  'FCA',
  'FAS',
  'FOB',
  'CFR',
  'CIF',
  'CPT',
  'CIP',
  'DAP',
  'DPU',
  'DDP',
];

const List<String> kPaymentMethodCodes = [
  'T/T',
  'L/C',
  'Western Union',
  'PayPal',
  'Escrow',
  'Cash',
];

const List<String> kCertificatePresets = [
  'ISO 9001',
  'ISO 14001',
  'CE',
  'FDA',
  'RoHS',
  'GMP',
  'BSCI',
];

String businessRoleTitle(String code) {
  final key = 'business_role_$code';
  final tr = key.tr;
  return tr == key ? code : tr;
}

/// S17 — Biznes ma'lumot tahrirlash. Logotip, kompaniya ma'lumotlari,
/// sertifikatlar va zavod rasmlari tahrirlanadi.
class EditBusinessInfoContent extends ScreenContent<EditBusinessInfoState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _seoCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _foundedCtrl;
  late final TextEditingController _moqCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _leadTimeCtrl;
  Worker? _formWorker;
  int _lastEpoch = -1;

  static const Map<String, String> _langNames = {
    'uz': 'Oʻzbekcha',
    'ru': 'Русский',
    'en': 'English',
    'tr': 'Türkçe',
    'zh': '中文',
    'ar': 'العربية',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'hi': 'हिन्दी',
    'ko': '한국어',
    'ja': '日本語',
    'pl': 'Polski',
    'uk': 'Українська',
    'kk': 'Қазақша',
    'fa': 'فارسی',
    'id': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
  };

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _seoCtrl = TextEditingController();
    _promptCtrl = TextEditingController();
    _foundedCtrl = TextEditingController();
    _moqCtrl = TextEditingController();
    _capacityCtrl = TextEditingController();
    _leadTimeCtrl = TextEditingController();
  }

  void _applyHydrate(EditBusinessInfoState state) {
    _nameCtrl.text = state.companyName.value;
    _websiteCtrl.text = state.website.value;
    _descriptionCtrl.text = state.description.value;
    _seoCtrl.text = state.seoText.value;
    _foundedCtrl.text = state.foundedYear.value?.toString() ?? '';
    _moqCtrl.text = state.moq.value;
    _capacityCtrl.text = state.productionCapacity.value;
    _leadTimeCtrl.text = state.leadTime.value;
    _lastEpoch = state.formEpoch.value;
  }

  void _bindHydrate(EditBusinessInfoState state) {
    _formWorker?.dispose();
    _formWorker = ever(state.formEpoch, (_) => _applyHydrate(state));
    if (state.formEpoch.value != _lastEpoch) {
      _applyHydrate(state);
    }
  }

  @override
  void onClose() {
    _formWorker?.dispose();
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _descriptionCtrl.dispose();
    _seoCtrl.dispose();
    _promptCtrl.dispose();
    _foundedCtrl.dispose();
    _moqCtrl.dispose();
    _capacityCtrl.dispose();
    _leadTimeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, EditBusinessInfoState state, FutureOr<void> Function(MyAction action) sendAction) {
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
                          shape: ProfileAvatarShape.circle,
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
                                value: state.role.value.isEmpty
                                    ? null
                                    : businessRoleTitle(state.role.value),
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
                    SizedBox(height: 20.dp),
                    _tradeAiSettingsCard(c, sendAction),
                    SizedBox(height: 16.dp),
                    _aiProfileCard(c, state, sendAction),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_description'.tr,
                      hint: 'business_description_hint'.tr,
                      controller: _descriptionCtrl,
                      maxLines: 5,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_seo'.tr,
                      hint: 'business_seo_hint'.tr,
                      controller: _seoCtrl,
                      maxLines: 4,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                    SizedBox(height: 12.dp),
                    Obx(() {
                      if (state.keywords.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'business_keywords'.tr,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8.dp),
                          Wrap(
                            spacing: 8.dp,
                            runSpacing: 8.dp,
                            children: [
                              for (final kw in state.keywords)
                                RemovableChip(
                                  label: kw,
                                  onRemove: () =>
                                      sendAction(RemoveAiKeyword(kw)),
                                ),
                            ],
                          ),
                          SizedBox(height: 12.dp),
                        ],
                      );
                    }),
                    Obx(() {
                      if (state.descriptionI18n.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  sendAction(ToggleAiTranslations()),
                              borderRadius: BorderRadius.circular(12.dp),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.dp),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'business_ai_translations'.trParams({
                                          'n': '${state.descriptionI18n.length}',
                                        }),
                                        style: TextStyle(
                                          color: c.accentText,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      state.showTranslations.value
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: c.accentText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (state.showTranslations.value) ...[
                            SizedBox(height: 6.dp),
                            ...state.descriptionI18n.entries.map((e) {
                              final title =
                                  _langNames[e.key] ?? e.key.toUpperCase();
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10.dp),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12.dp),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(12.dp),
                                    border: Border.all(
                                      color: c.surfaceBorder,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 4.dp),
                                      Text(
                                        e.value,
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 13.sp,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                          SizedBox(height: 8.dp),
                        ],
                      );
                    }),
                    AppTextField(
                      label: 'business_founded_year'.tr,
                      hint: 'business_founded_year_hint'.tr,
                      controller: _foundedCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 20.dp),
                    Text(
                      'business_trade_section'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12.dp),
                    AppTextField(
                      label: 'business_moq'.tr,
                      hint: 'business_moq_hint'.tr,
                      controller: _moqCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_capacity'.tr,
                      hint: 'business_capacity_hint'.tr,
                      controller: _capacityCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'business_lead_time'.tr,
                      hint: 'business_lead_time_hint'.tr,
                      controller: _leadTimeCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    Text(
                      'business_incoterms'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 8.dp,
                          runSpacing: 8.dp,
                          children: [
                            for (final code in kIncotermCodes)
                              _SelectChip(
                                label: code,
                                selected: state.incoterms.contains(code),
                                onTap: () => sendAction(ToggleIncoterm(code)),
                              ),
                          ],
                        )),
                    SizedBox(height: 16.dp),
                    Text(
                      'business_payment_methods'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 8.dp,
                          runSpacing: 8.dp,
                          children: [
                            for (final code in kPaymentMethodCodes)
                              _SelectChip(
                                label: code,
                                selected: state.paymentMethods.contains(code),
                                onTap: () =>
                                    sendAction(TogglePaymentMethod(code)),
                              ),
                          ],
                        )),
                    SizedBox(height: 20.dp),
                    Text(
                      'business_export_countries'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            for (final code in state.exportCountries)
                              RemovableChip(
                                label: formatCountryName(code),
                                onRemove: () =>
                                    sendAction(RemoveExportCountry(code)),
                              ),
                            RemovableChip.add(
                              label: 'business_add_export_country'.tr,
                              onTap: () =>
                                  sendAction(AddExportCountryRequested()),
                            ),
                          ],
                        )),
                    SizedBox(height: 20.dp),
                    Text(
                      'factory_verification_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'factory_verification_hint'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() {
                      final chips = <Widget>[
                        if (state.factoryVerified.value)
                          _SelectChip(
                            label: 'factory_verified'.tr,
                            selected: true,
                            onTap: () {},
                          ),
                        if (state.inspectionPassed.value)
                          _SelectChip(
                            label: 'factory_inspection_passed'.tr,
                            selected: true,
                            onTap: () {},
                          ),
                      ];
                      if (chips.isEmpty) {
                        return Text(
                          'factory_verification_pending'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13.sp,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8.dp,
                        runSpacing: 8.dp,
                        children: chips,
                      );
                    }),
                    SizedBox(height: 12.dp),
                    Obx(() {
                      final url = state.auditReportUrl.value;
                      if (url == null || url.isEmpty) {
                        return MediaTile.upload(
                          uploadLabel: 'factory_audit_upload'.tr,
                          onTap: () =>
                              sendAction(UploadAuditReportRequested()),
                        );
                      }
                      return Wrap(
                        spacing: 10.dp,
                        runSpacing: 10.dp,
                        children: [
                          MediaTile.image(
                            imageUrl: url,
                            gradient: prodOliveGradient,
                            onTap: () => sendAction(OpenAuditReport()),
                            onRemove: () => sendAction(RemoveAuditReport()),
                          ),
                        ],
                      );
                    }),
                    SizedBox(height: 20.dp),
                    Text(
                      'business_certificates'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'business_certificates_hint'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 8.dp,
                          runSpacing: 8.dp,
                          children: [
                            for (final code in kCertificatePresets)
                              _SelectChip(
                                label: code,
                                selected: state.certificates.contains(code),
                                onTap: () =>
                                    sendAction(ToggleCertificatePreset(code)),
                              ),
                          ],
                        )),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            for (final cert in state.certificates.where(
                              (e) => !kCertificatePresets.contains(e),
                            ))
                              RemovableChip(
                                label: cert,
                                onRemove: () =>
                                    sendAction(RemoveCertificate(cert)),
                              ),
                            RemovableChip.add(
                              label: 'business_add_certificate'.tr,
                              onTap: () =>
                                  sendAction(AddCertificateRequested()),
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
    final yearRaw = _foundedCtrl.text.trim();
    final year = int.tryParse(yearRaw);
    if (yearRaw.isNotEmpty) {
      state.foundedYear.value = year;
    } else {
      state.foundedYear.value = null;
    }
    state.moq.value = _moqCtrl.text.trim();
    state.productionCapacity.value = _capacityCtrl.text.trim();
    state.leadTime.value = _leadTimeCtrl.text.trim();
    sendAction(SaveBusinessInfo(
      companyName: _nameCtrl.text,
      website: _websiteCtrl.text,
      description: _descriptionCtrl.text,
      seoText: _seoCtrl.text,
    ));
  }

  Widget _tradeAiSettingsCard(
    AppColors c,
    void Function(MyAction) sendAction,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => sendAction(OpenTradeAiSettings()),
        borderRadius: BorderRadius.circular(16.dp),
        child: Ink(
          padding: EdgeInsets.all(14.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(
              color: c.accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: c.accentText, size: 22.dp),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'trade_ai_settings_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      'trade_ai_settings_card_desc'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 22.dp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiProfileCard(
    AppColors c,
    EditBusinessInfoState state,
    void Function(MyAction) sendAction,
  ) {
    return Container(
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: c.accentText, size: 18.dp),
              SizedBox(width: 8.dp),
              Expanded(
                child: Text(
                  'business_ai_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.dp),
          Text(
            'business_ai_desc'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              height: 1.35,
            ),
          ),
          SizedBox(height: 12.dp),
          AppTextField(
            label: 'business_ai_prompt'.tr,
            hint: 'business_ai_prompt_hint'.tr,
            controller: _promptCtrl,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          SizedBox(height: 12.dp),
          Obx(
            () => PrimaryButton(
              text: 'business_ai_generate'.tr,
              isLoading: state.aiGenerating.value,
              enabled: !state.aiGenerating.value && !state.isSaving.value,
              onTap: () => sendAction(
                GenerateAiProfile(
                  _promptCtrl.text,
                  companyName: _nameCtrl.text,
                ),
              ),
              startIcon: Icon(
                Icons.auto_awesome_rounded,
                color: c.onAccent,
                size: 18.dp,
              ),
            ),
          ),
        ],
      ),
    );
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
    final labels = kBusinessRoleCodes.map(businessRoleTitle).toList();
    final selectedLabel = state.role.value.isEmpty
        ? null
        : businessRoleTitle(state.role.value);
    final picked = await showSimpleListPickerBottomSheet(
      context,
      title: 'business_role'.tr,
      items: labels,
      selected: selectedLabel,
    );
    if (picked == null) return;
    final idx = labels.indexOf(picked);
    if (idx < 0) return;
    sendAction(SelectBusinessRole(kBusinessRoleCodes[idx]));
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: selected ? c.accent : (c.isDark ? const Color(0x66152A42) : const Color(0xCCFFFFFF)),
            borderRadius: BorderRadius.circular(999.dp),
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.onAccent : c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
