import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../modal/image_picker.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'edit_business_info_action.dart';
import 'edit_business_info_content.dart';
import 'edit_business_info_state.dart';

const _roleToApi = {
  'Ishlab chiqaruvchi': 'manufacturer',
  'Distributor': 'distributor',
  'Chakana savdo': 'retail',
  'Xizmat ko‘rsatuvchi': 'service',
};

const _apiToRole = {
  'manufacturer': 'Ishlab chiqaruvchi',
  'distributor': 'Distributor',
  'retail': 'Chakana savdo',
  'service': 'Xizmat ko‘rsatuvchi',
};

class EditBusinessInfoScreen extends Screen<EditBusinessInfoState, void> {
  EditBusinessInfoScreen() : super(mobileContent: EditBusinessInfoContent());

  @override
  void initState(void payload) {
    state.factoryImages.clear();
    state.certificates.clear();
    state.companyName.value = '';
    state.website.value = '';
    state.description.value = '';
    state.logoUrl.value = null;
    state.loading.value = true;
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    final result = await Get.find<ProfileRepository>().getBusiness();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.companyName.value = (map['company_name'] as String?) ?? '';
        state.country.value = (map['country'] as String?) ?? '';
        state.role.value =
            _apiToRole[(map['business_role'] as String?) ?? ''] ??
                'Ishlab chiqaruvchi';
        state.website.value = (map['website'] as String?) ?? '';
        state.description.value = (map['description'] as String?) ?? '';
        final logo = map['logo_url']?.toString();
        state.logoUrl.value =
            (logo != null && logo.isNotEmpty) ? logo : null;
        final certs = map['certificates'];
        if (certs is List) {
          state.certificates.assignAll(certs.map((e) => e.toString()));
        } else {
          state.certificates.clear();
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
        state.formEpoch.value++;
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  @override
  Future<void> actionHandler(
    EditBusinessInfoState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
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
      case AddCertificateRequested _:
        final ctrl = TextEditingController();
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
      case SaveBusinessInfo a:
        state.isSaving.value = true;
        try {
          final body = <String, dynamic>{
            if (a.companyName.trim().isNotEmpty)
              'company_name': a.companyName.trim(),
            if (state.country.value.length == 2)
              'country': state.country.value.toUpperCase(),
            if (_roleToApi[state.role.value] != null)
              'business_role': _roleToApi[state.role.value],
            if (a.website.trim().isNotEmpty) 'website': a.website.trim(),
            if (a.description.trim().isNotEmpty)
              'description': a.description.trim(),
            'certificates': state.certificates.toList(),
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
}
