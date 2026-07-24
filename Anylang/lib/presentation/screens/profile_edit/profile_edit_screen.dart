import 'dart:async';

import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/image_picker.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../profile/profile_account.dart';
import 'profile_edit_action.dart';
import 'profile_edit_content.dart';
import 'profile_edit_state.dart';

class ProfileEditScreen extends Screen<ProfileEditState, ProfileAccount> {
  ProfileEditScreen() : super(mobileContent: ProfileEditContent());

  @override
  void initState(ProfileAccount? payload) {
    state.isSaving.value = false;
    state.account.value = payload;
    state.country.value = payload?.countryCode ?? '';
    state.gender.value = 'male';
    state.birthDate.value = null;
    if (payload != null) state.formEpoch.value++;
    unawaited(_hydrateFromApi());
  }

  Future<void> _hydrateFromApi() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
        final acc = ProfileAccount.fromApi(map);
        state.account.value = acc;
        final code = (map['country'] as String?)?.trim().toUpperCase() ?? '';
        if (code.length == 2) {
          state.country.value = code;
        } else if (acc.countryCode.isNotEmpty) {
          state.country.value = acc.countryCode;
        }
        final g = (map['gender'] as String?)?.toLowerCase();
        state.gender.value = (g == 'female' || g == 'male') ? g! : 'male';
        final bd = map['birth_date']?.toString();
        if (bd != null && bd.isNotEmpty) {
          state.birthDate.value = DateTime.tryParse(bd);
        }
        state.formEpoch.value++;
      },
      failure: showAppError,
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Future<void> actionHandler(ProfileEditState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case ChangeProfilePhoto _:
        final file = await pickImage(context);
        if (file == null) return;
        state.isSaving.value = true;
        try {
          final acc = state.account.value;
          final result = acc?.isBusiness == true
              ? await Get.find<ProfileRepository>()
                  .uploadBusinessLogo(file.path)
              : await Get.find<ProfileRepository>().uploadAvatar(file.path);
          await result.when(
            success: (data) async {
              final map = asMap(data);
              final url = map?['avatar_url']?.toString() ??
                  map?['logo_url']?.toString() ??
                  map?['url']?.toString();
              if (acc != null && url != null && url.isNotEmpty) {
                state.account.value = acc.copyWith(
                  avatarUrl: url,
                  initial: initialsOf(acc.name),
                );
              }
              state.avatarEpoch.value++;
              final me = await Get.find<ProfileRepository>().getMe();
              me.when(
                success: (raw) {
                  final m = asMap(raw);
                  if (m != null) {
                    unawaited(
                      SessionStore.saveUser(Map<String, dynamic>.from(m)),
                    );
                    state.account.value = ProfileAccount.fromApi(m);
                    state.avatarEpoch.value++;
                  }
                },
                failure: (_) {},
              );
              showAppMessage('profile_avatar_updated'.tr);
            },
            failure: (e) async => showAppError(e),
          );
        } finally {
          state.isSaving.value = false;
        }
      case SelectProfileBirthDate a:
        state.birthDate.value = a.date;
      case SelectProfileCountry a:
        state.country.value = a.country.toUpperCase();
      case SelectProfileGender a:
        state.gender.value = a.gender;
      case SaveProfileEdit a:
        final name = a.fullName.trim();
        if (name.length < 2) {
          showAppError('name_too_short'.tr);
          return;
        }
        state.isSaving.value = true;
        try {
          final body = <String, dynamic>{
            'full_name': name,
            if (state.birthDate.value != null)
              'birth_date': _fmtDate(state.birthDate.value!),
            if (state.gender.value == 'male' || state.gender.value == 'female')
              'gender': state.gender.value,
            if (state.country.value.length == 2)
              'country': state.country.value.toUpperCase(),
          };
          final result = await Get.find<ProfileRepository>().updateMe(body);
          await result.when(
            success: (data) async {
              final map = asMap(data);
              if (map != null) {
                await SessionStore.saveUser(Map<String, dynamic>.from(map));
                state.account.value = ProfileAccount.fromApi(map);
              }
              showAppMessage('profile_saved'.tr);
              popBackNavigate();
            },
            failure: (e) async => showAppError(e),
          );
        } finally {
          state.isSaving.value = false;
        }
    }
  }
}
