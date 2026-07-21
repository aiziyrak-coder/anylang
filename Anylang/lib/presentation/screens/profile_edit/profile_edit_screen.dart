import '../../modal/image_picker.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../profile/profile_account.dart';
import 'profile_edit_action.dart';
import 'profile_edit_content.dart';
import 'profile_edit_state.dart';

/// S19 — Profil tahrirlash. `ProfileScreen`dagi "Tahrirlash" tugmasidan joriy
/// `ProfileAccount` payload sifatida keladi (qayta backenddan yuklanmaydi).
class ProfileEditScreen extends Screen<ProfileEditState, ProfileAccount> {

  ProfileEditScreen() : super(
    mobileContent: ProfileEditContent(),
  );

  @override
  void initState(ProfileAccount? payload) {
    state.account = payload;
    state.country.value = payload?.country ?? '';
    // TODO: tug'ilgan sana va jins hali backenddan kelmaydi — mock.
    state.birthDate.value = DateTime(1998, 3, 14);
    state.gender.value = 'female';
  }

  @override
  Future<void> actionHandler(ProfileEditState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case ChangeProfilePhoto _:
        await pickImage(context);
        // TODO: tanlangan rasmni yuklash so'rovi.
      case SelectProfileBirthDate a:
        state.birthDate.value = a.date;
      case SelectProfileCountry a:
        state.country.value = a.country;
      case SelectProfileGender a:
        state.gender.value = a.gender;
      case SaveProfileEdit _:
        state.isSaving.value = true;
        // TODO: haqiqiy saqlash so'rovi.
        state.isSaving.value = false;
        popBackNavigate();
    }
  }
}
