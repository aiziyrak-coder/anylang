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

class SupportOpenHistory extends SupportChatAction {}

class SupportLoadSession extends SupportChatAction {
  final int sessionId;
  SupportLoadSession(this.sessionId);
}

class SupportSubmitRating extends SupportChatAction {
  final int stars;
  SupportSubmitRating(this.stars);
}

class SupportDismissRating extends SupportChatAction {}
