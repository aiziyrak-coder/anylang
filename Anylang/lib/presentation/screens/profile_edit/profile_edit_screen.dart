import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
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
    state.account.value = payload;
    state.country.value = payload?.countryCode ?? '';
    state.gender.value = 'male';
    if (payload != null) state.formEpoch.value++;
    _hydrateFromApi();
  }

  Future<void> _hydrateFromApi() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final acc = ProfileAccount.fromApi(map);
        state.account.value = acc;
        final code = (map['country'] as String?)?.trim().toUpperCase() ?? '';
        if (code.length == 2) {
          state.country.value = code;
        } else if (acc.countryCode.isNotEmpty) {
          state.country.value = acc.countryCode;
        }
        state.gender.value = (map['gender'] as String?) ?? 'male';
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
          final result =
              await Get.find<ProfileRepository>().uploadAvatar(file.path);
          result.when(
            success: (data) {
              final map = asMap(data);
              final url =
                  map?['avatar_url']?.toString() ?? map?['url']?.toString();
              final acc = state.account.value;
              if (acc != null && url != null) {
                state.account.value = acc.copyWith(
                  avatarUrl: url,
                  initial: initialsOf(acc.name),
                );
              }
              state.avatarEpoch.value++;
              showAppMessage('profile_avatar_updated'.tr);
            },
            failure: showAppError,
          );
        } finally {
          state.isSaving.value = false;
        }
      case SelectProfileBirthDate a:
        state.birthDate.value = a.date;
      case SelectProfileCountry a:
        state.country.value = a.country;
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
            if (state.gender.value.isNotEmpty) 'gender': state.gender.value,
            if (state.country.value.length == 2)
              'country': state.country.value.toUpperCase(),
          };
          final result = await Get.find<ProfileRepository>().updateMe(body);
          result.when(
            success: (_) {
              showAppMessage('profile_saved'.tr);
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
