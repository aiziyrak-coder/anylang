import '../../utils/screen_options/my_action.dart';

/// Faqat Verify ekraniga xos action'lar.
class VerifyAction extends MyAction {}

class CodeChanged extends VerifyAction {
  final String code;
  CodeChanged(this.code);
}

class ResendCode extends VerifyAction {}

class VerifySubmit extends VerifyAction {
  final String code;
  VerifySubmit(this.code);
}
