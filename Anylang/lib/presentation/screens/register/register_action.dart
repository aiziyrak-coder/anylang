import '../../utils/screen_options/my_action.dart';

/// Faqat Register ekraniga xos action'lar.
class RegisterAction extends MyAction {}

class SelectGender extends RegisterAction {
  final String gender;
  SelectGender(this.gender);
}

class SelectBirthDate extends RegisterAction {
  final DateTime date;
  SelectBirthDate(this.date);
}

class SelectCountry extends RegisterAction {
  final String name;
  final String code;
  SelectCountry(this.name, this.code);
}

class ToggleTerms extends RegisterAction {
  final bool value;
  ToggleTerms(this.value);
}

class RegisterSubmit extends RegisterAction {
  final String fullName;
  final String email;
  final String password;
  RegisterSubmit(this.fullName, this.email, this.password);
}
