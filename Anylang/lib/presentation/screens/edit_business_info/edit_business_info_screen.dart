import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../modal/image_picker.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../trade_ai_settings/trade_ai_settings_screen.dart';
import 'edit_business_info_action.dart';
import 'edit_business_info_content.dart';
import 'edit_business_info_state.dart';

const _roleCodes = ['manufacturer', 'distributor', 'retail', 'service'];

class EditBusinessInfoScreen extends Screen<EditBusinessInfoState, void> {
  EditBusinessInfoScreen() : super(mobileContent: EditBusinessInfoContent());

  String _baselineSnapshot = '';

  @override
  void initState(void payload) {
    state.factoryImages.clear();
    state.certificates.clear();
    state.exportCountries.clear();
    state.incoterms.clear();
    state.paymentMethods.clear();
    state.keywords.clear();
    state.descriptionI18n.clear();
    state.companyName.value = '';
    state.website.value = '';
    state.description.value = '';
    state.seoText.value = '';
    state.aiPrompt.value = '';
    state.aiGenerating.value = false;
    state.showTranslations.value = false;
    state.foundedYear.value = null;
    state.moq.value = '';
    state.productionCapacity.value = '';
    state.leadTime.value = '';
    state.logoUrl.value = null;
    state.role.value = 'manufacturer';
    state.loading.value = true;
    _load();
  }

  String _snapshot(EditBusinessInfoState s) =>
      '${s.companyName.value}|${s.website.value}|${s.description.value}|${s.seoText.value}|${s.country.value}|${s.role.value}';

  Future<void> _load() async {
    state.loading.value = true;
    state.loadError.value = null;
    try {
      final result = await Get.find<ProfileRepository>().getBusiness();
      result.when(
        success: (data) {
          final map = asMap(data);
          if (map == null) {
            state.loadError.value = 'business_load_failed'.tr;
            return;
          }
        state.companyName.value = (map['company_name'] as String?) ?? '';
        state.country.value = (map['country'] as String?) ?? '';
        final role = (map['business_role'] as String?) ?? 'manufacturer';
        state.role.value = _roleCodes.contains(role) ? role : 'manufacturer';
        state.website.value = (map['website'] as String?) ?? '';
        state.description.value = (map['description'] as String?) ?? '';
        state.seoText.value = (map['seo_text'] as String?) ?? '';
        final kws = map['keywords'];
        if (kws is List) {
          state.keywords.assignAll(kws.map((e) => e.toString()));
        } else {
          state.keywords.clear();
        }
        final i18n = map['description_i18n'];
        state.descriptionI18n.clear();
        if (i18n is Map) {
          i18n.forEach((k, v) {
            final code = k.toString();
            final text = v?.toString() ?? '';
            if (code.isNotEmpty && text.isNotEmpty) {
              state.descriptionI18n[code] = text;
            }
          });
        }
        state.foundedYear.value = (map['founded_year'] as num?)?.toInt();
        state.moq.value = (map['moq'] as String?)?.trim() ?? '';
        state.productionCapacity.value =
            (map['production_capacity'] as String?)?.trim() ?? '';
        state.leadTime.value = (map['lead_time'] as String?)?.trim() ?? '';
        final logo = map['logo_url']?.toString();
        state.logoUrl.value = (logo != null && logo.isNotEmpty) ? logo : null;
        final certs = map['certificates'];
        if (certs is List) {
          state.certificates.assignAll(certs.map((e) => e.toString()));
        } else {
          state.certificates.clear();
        }
        final countries = map['export_countries'];
        if (countries is List) {
          state.exportCountries.assignAll(
            countries
                .map((e) => e.toString().trim().toUpperCase())
                .where((e) => e.length == 2),
          );
        } else {
          state.exportCountries.clear();
        }
        final incoterms = map['incoterms'];
        if (incoterms is List) {
          state.incoterms.assignAll(incoterms.map((e) => e.toString()));
        } else {
          state.incoterms.clear();
        }
        final payments = map['payment_methods'];
        if (payments is List) {
          state.paymentMethods.assignAll(payments.map((e) => e.toString()));
        } else {
          state.paymentMethods.clear();
        }
        final images = map['factory_images'];
        final items = <FactoryImageItem>[];
        if (images is List) {
          for (final e in images) {
            if (e is! Map) continue;
            final id = (e['id'] as num?)?.toInt() ?? 0;
            final url = e['url']?.toString() ?? '';
            if (url.isNotEmpty) {
              items.add(FactoryImageItem(id: id, url: url));
            }
          }
        }
        state.factoryImages.assignAll(items);
        final fv = map['factory_verification'];
        if (fv is Map) {
          state.factoryVerified.value = fv['factory_verified'] == true;
          state.inspectionPassed.value = fv['inspection_passed'] == true;
          final audit = fv['audit_report_url']?.toString().trim();
          state.auditReportUrl.value =
              (audit != null && audit.isNotEmpty) ? audit : null;
        } else {
          state.factoryVerified.value = map['factory_verified'] == true;
          state.inspectionPassed.value = map['inspection_passed'] == true;
          final audit = map['audit_report_url']?.toString().trim();
          state.auditReportUrl.value =
              (audit != null && audit.isNotEmpty) ? audit : null;
        }
        state.formEpoch.value++;
        _baselineSnapshot = _snapshot(state);
      },
      failure: (err) {
        state.loadError.value = AuthValidators.safeError(
          err,
          fallbackKey: 'business_load_failed',
        );
      },
    );
    } finally {
      state.loading.value = false;
    }
  }

  bool _isDirty(EditBusinessInfoState s) =>
      _baselineSnapshot.isNotEmpty && _snapshot(s) != _baselineSnapshot;

  Future<bool> _confirmDiscard() async {
    final leave = await Get.dialog<bool>(
      AlertDialog(
        title: Text('business_unsaved_title'.tr),
        content: Text('business_unsaved_back'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Future<void> actionHandler(
    EditBusinessInfoState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        if (state.isSaving.value) return;
        if (_isDirty(state)) {
          final ok = await _confirmDiscard();
          if (!ok) return;
        }
        popBackNavigate();
      case ChangeLogo _:
        final file = await pickImage(context);
        if (file == null) return;
        state.isSaving.value = true;
        try {
          final result =
              await Get.find<ProfileRepository>().uploadBusinessLogo(file.path);
          result.when(
            success: (data) {
              final map = asMap(data);
              final url =
                  map?['logo_url']?.toString() ?? map?['url']?.toString();
              if (url != null && url.isNotEmpty) {
                state.logoUrl.value = url;
              }
              showAppMessage('business_logo_updated'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
      case SelectBusinessCountry a:
        state.country.value = a.country;
      case SelectBusinessRole a:
        state.role.value = a.role;
      case RemoveCertificate a:
        state.certificates.remove(a.certificate);
      case AddExportCountryRequested _:
        final picked = await showCountryPickerBottomSheet(
          context,
          title: 'business_export_countries'.tr,
          desc: 'business_add_export_country'.tr,
        );
        if (picked == null) return;
        final code = picked.code.toUpperCase();
        if (!state.exportCountries.contains(code)) {
          state.exportCountries.add(code);
        }
      case RemoveExportCountry a:
        state.exportCountries.remove(a.code);
      case TogglePaymentMethod a:
        if (state.paymentMethods.contains(a.code)) {
          state.paymentMethods.remove(a.code);
        } else {
          state.paymentMethods.add(a.code);
        }
      case ToggleCertificatePreset a:
        if (state.certificates.contains(a.code)) {
          state.certificates.remove(a.code);
        } else {
          state.certificates.add(a.code);
        }
      case AddCertificateRequested _:
        final ctrl = TextEditingController();
        try {
          final name = await Get.dialog<String>(
            AlertDialog(
              title: Text('business_certificate_title'.tr),
              content: TextField(controller: ctrl, autofocus: true),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('cancel'.tr),
                ),
                TextButton(
                  onPressed: () => Get.back(result: ctrl.text.trim()),
                  child: Text('confirm'.tr),
                ),
              ],
            ),
          );
          if (name != null && name.isNotEmpty) state.certificates.add(name);
        } finally {
          ctrl.dispose();
        }
      case AddFactoryImageRequested _:
        final file = await pickImage(context);
        if (file == null) return;
        state.isSaving.value = true;
        try {
          final result = await Get.find<ProfileRepository>()
              .uploadFactoryImage(file.path);
          result.when(
            success: (data) {
              final map = asMap(data);
              final id = (map?['id'] as num?)?.toInt() ?? 0;
              final url = map?['url']?.toString() ?? '';
              if (url.isNotEmpty) {
                state.factoryImages.add(FactoryImageItem(id: id, url: url));
              }
              showAppMessage('business_factory_uploaded'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
      case OpenFactoryImage a:
        await showFullScreenImage(context, url: a.url);
      case UploadAuditReportRequested _:
        final file = await pickImage(context);
        if (file == null) return;
        state.isSaving.value = true;
        try {
          final result =
              await Get.find<ProfileRepository>().uploadAuditReport(file.path);
          result.when(
            success: (data) {
              final map = asMap(data);
              final url = map?['audit_report_url']?.toString() ?? '';
              if (url.isNotEmpty) {
                state.auditReportUrl.value = url;
              }
              showAppMessage('factory_audit_uploaded'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
      case OpenAuditReport _:
        final url = state.auditReportUrl.value;
        if (url != null && url.isNotEmpty) {
          await showFullScreenImage(context, url: url);
        }
      case RemoveAuditReport _:
        state.isSaving.value = true;
        try {
          final result = await Get.find<ProfileRepository>().deleteAuditReport();
          result.when(
            success: (_) {
              state.auditReportUrl.value = null;
              showAppMessage('action_done'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
      case GenerateAiProfile a:
        if (a.companyName.trim().isNotEmpty) {
          state.companyName.value = a.companyName.trim();
        }
        await _generateAi(state, a.prompt);
      case OpenTradeAiSettings _:
        await navigate(TradeAiSettingsScreen());
      case ToggleAiTranslations _:
        state.showTranslations.value = !state.showTranslations.value;
      case RemoveAiKeyword a:
        state.keywords.remove(a.keyword);
      case SaveBusinessInfo a:
        state.isSaving.value = true;
        try {
          final body = <String, dynamic>{
            if (a.companyName.trim().isNotEmpty)
              'company_name': a.companyName.trim(),
            if (state.country.value.length == 2)
              'country': state.country.value.toUpperCase(),
            if (_roleCodes.contains(state.role.value))
              'business_role': state.role.value,
            'website': a.website.trim(),
            'description': a.description.trim(),
            'seo_text': a.seoText.trim(),
            'keywords': state.keywords.toList(),
            'description_i18n': Map<String, String>.from(state.descriptionI18n),
            'certificates': state.certificates.toList(),
            'export_countries': state.exportCountries.toList(),
            'moq': state.moq.value,
            'production_capacity': state.productionCapacity.value,
            'lead_time': '',
            'incoterms': <String>[],
            'payment_methods': state.paymentMethods.toList(),
            if (state.foundedYear.value != null)
              'founded_year': state.foundedYear.value,
          };
          final result =
              await Get.find<ProfileRepository>().updateBusiness(body);
          result.when(
            success: (_) {
              showAppMessage('business_saved'.tr);
              popBackNavigate();
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
    }
  }

  Future<void> _generateAi(EditBusinessInfoState state, String raw) async {
    final prompt = raw.trim();
    if (prompt.length < 8) {
      showAppWarning('business_ai_prompt_min'.tr);
      return;
    }
    if (state.aiGenerating.value) return;
    state.aiGenerating.value = true;
    final locale = SessionStore.preferredLanguage().isNotEmpty
        ? SessionStore.preferredLanguage()
        : (Get.locale?.languageCode ?? 'uz');
    final result = await Get.find<ProfileRepository>().generateAiCompanyProfile(
      prompt: prompt,
      companyName: state.companyName.value.isNotEmpty
          ? state.companyName.value
          : null,
      country: state.country.value.length == 2 ? state.country.value : null,
      businessRole: state.role.value,
      locale: locale,
    );
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final description = (map['description']?.toString() ?? '').trim();
        final seo = (map['seo_text']?.toString() ?? '').trim();
        if (description.isNotEmpty) state.description.value = description;
        if (seo.isNotEmpty) state.seoText.value = seo;
        final kws = map['keywords'];
        if (kws is List) {
          state.keywords.assignAll(
            kws.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
          );
        }
        final i18n = map['translations'] ?? map['description_i18n'];
        state.descriptionI18n.clear();
        if (i18n is Map) {
          i18n.forEach((k, v) {
            final code = k.toString();
            final text = (v?.toString() ?? '').trim();
            if (code.isNotEmpty && text.isNotEmpty) {
              state.descriptionI18n[code] = text;
            }
          });
        }
        state.showTranslations.value = state.descriptionI18n.isNotEmpty;
        state.formEpoch.value++;
        showAppMessage('business_ai_filled'.tr);
      },
      failure: showAppError,
    );
    state.aiGenerating.value = false;
  }
}
