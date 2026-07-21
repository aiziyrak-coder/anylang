import '../../utils/screen_options/my_action.dart';

class LoginAction extends MyAction {}

class LoginSubmit extends LoginAction {
  final String email;
  final String password;
  LoginSubmit(this.email, this.password);
}

class GoToRegister extends LoginAction {}

class GoogleLogin extends LoginAction {}

class ForgotPassword extends LoginAction {}

class GoToRestoreAccount extends LoginAction {}
