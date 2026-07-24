import '../../utils/screen_options/my_action.dart';

/// Faqat Profil tahrirlash ekraniga xos action'lar.
class ProfileEditAction extends MyAction {}

class ChangeProfilePhoto extends ProfileEditAction {}

class SelectProfileBirthDate extends ProfileEditAction {
  final DateTime? date;
  SelectProfileBirthDate(this.date);
}

class SelectProfileCountry extends ProfileEditAction {
  final String country;
  SelectProfileCountry(this.country);
}

class SelectProfileGender extends ProfileEditAction {
  final String gender;
  SelectProfileGender(this.gender);
}

class SaveProfileEdit extends ProfileEditAction {
  final String fullName;
  final String email;
  SaveProfileEdit({required this.fullName, required this.email});
}
