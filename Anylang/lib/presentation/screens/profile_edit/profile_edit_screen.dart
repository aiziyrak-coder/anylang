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
    state.account = payload;
    state.country.value = payload?.countryCode ?? '';
    state.gender.value = 'male';
    _hydrateFromApi();
  }

  Future<void> _hydrateFromApi() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.account = ProfileAccount.fromApi(map);
        final code = (map['country'] as String?)?.trim().toUpperCase() ?? '';
        if (code.length == 2) {
          state.country.value = code;
        } else if (state.account?.countryCode.isNotEmpty == true) {
          state.country.value = state.account!.countryCode;
        }
        state.gender.value = (map['gender'] as String?) ?? 'male';
        final bd = map['birth_date']?.toString();
        if (bd != null && bd.isNotEmpty) {
          state.birthDate.value = DateTime.tryParse(bd);
        }
      },
      failure: (_) {},
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
          final result = await Get.find<ProfileRepository>().uploadAvatar(file.path);
          result.when(
            success: (_) {},
            failure: (_) {},
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
          showAppError('Ism juda qisqa');
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
              popBackNavigate();
            },
            failure: (_) {},
          );
        } finally {
          state.isSaving.value = false;
        }
    }
  }
}
