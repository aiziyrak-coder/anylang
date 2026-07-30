import 'dart:async';

import 'package:flutter/foundation.dart';
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

  void _applyGenderFromMap(Map<String, dynamic> map) {
    final g = (map['gender'] as String?)?.toLowerCase();
    if (g == 'female' || g == 'male') {
      state.gender.value = g!;
    }
  }

  void _seedFromSession() {
    final user = SessionStore.user();
    if (user == null) return;
    _applyGenderFromMap(user);
    final bd = user['birth_date']?.toString();
    if (bd != null && bd.isNotEmpty) {
      state.birthDate.value = DateTime.tryParse(bd);
    }
    final code = (user['country'] as String?)?.trim().toUpperCase() ?? '';
    if (code.length == 2) {
      state.country.value = code;
    }
  }

  @override
  void initState(ProfileAccount? payload) {
    state.isSaving.value = false;
    state.avatarUploading.value = false;
    state.hydrateFailed.value = false;
    state.dirty.value = false;
    state.account.value = payload;
    state.country.value = payload?.countryCode ?? '';
    state.birthDate.value = null;
    _seedFromSession();
    if (payload != null) state.formEpoch.value++;
    unawaited(_hydrateFromApi());
  }

  Future<void> _hydrateFromApi() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        state.hydrateFailed.value = false;
        final map = asMap(data);
        if (map == null) {
          state.hydrateFailed.value = true;
          return;
        }
        unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
        final acc = ProfileAccount.fromApi(map);
        state.account.value = acc;
        // Agar foydalanuvchi allaqachon tahrirlayotgan bo‘lsa — formani
        // qayta yozib yubormaymiz (faqat account/session yangilanadi).
        if (state.dirty.value) return;
        final code = (map['country'] as String?)?.trim().toUpperCase() ?? '';
        if (code.length == 2) {
          state.country.value = code;
        } else if (acc.countryCode.isNotEmpty) {
          state.country.value = acc.countryCode;
        }
        _applyGenderFromMap(map);
        final bd = map['birth_date']?.toString();
        if (bd != null && bd.isNotEmpty) {
          state.birthDate.value = DateTime.tryParse(bd);
        }
        state.formEpoch.value++;
      },
      failure: (err) {
        state.hydrateFailed.value = true;
        showAppError(err);
      },
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  bool _validateBirthDate(DateTime date) {
    final now = DateTime.now();
    if (date.isAfter(now)) {
      showAppError('birth_date_future'.tr);
      return false;
    }
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    if (age < 13) {
      showAppError('birth_too_young'.tr);
      return false;
    }
    return true;
  }

  @override
  Future<void> actionHandler(ProfileEditState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case ChangeProfilePhoto _:
        final file = await pickImage(context);
        if (file == null) return;
        state.avatarUploading.value = true;
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
                failure: (err) {
                  debugPrint('avatar getMe failed: $err');
                },
              );
              showAppMessage('profile_avatar_updated'.tr);
            },
            failure: (e) async => showAppError(e),
          );
        } finally {
          state.avatarUploading.value = false;
        }
      case SelectProfileBirthDate a:
        state.dirty.value = true;
        state.birthDate.value = a.date;
      case SelectProfileCountry a:
        state.dirty.value = true;
        state.country.value = a.country.toUpperCase();
      case SelectProfileGender a:
        state.dirty.value = true;
        state.gender.value = a.gender;
      case SaveProfileEdit a:
        if (state.hydrateFailed.value) {
          showAppError('profile_edit_hydrate_failed'.tr);
          return;
        }
        final name = a.fullName.trim();
        if (name.length < 2) {
          showAppError('name_too_short'.tr);
          return;
        }
        final bd = state.birthDate.value;
        if (bd != null && !_validateBirthDate(bd)) {
          return;
        }
        state.isSaving.value = true;
        try {
          final body = <String, dynamic>{
            'full_name': name,
            if (bd != null) 'birth_date': _fmtDate(bd),
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
