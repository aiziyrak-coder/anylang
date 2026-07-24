import '../../utils/screen_options/my_action.dart';

class SupportChatAction extends MyAction {}

class SupportSend extends SupportChatAction {
  final String text;
  SupportSend(this.text);
}

class SupportComposerChanged extends SupportChatAction {
  final String text;
  SupportComposerChanged(this.text);
}
