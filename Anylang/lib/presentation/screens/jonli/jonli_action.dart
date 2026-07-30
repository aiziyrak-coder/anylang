import '../../utils/screen_options/my_action.dart';
import '../select_language/select_language_option.dart';

/// Faqat Jonli ekraniga xos action'lar.
class JonliAction extends MyAction {}

/// Gapiruvchi tarafni bosib turish (men / suhbatdosh).
class HoldSpeakStart extends JonliAction {
  final bool isMe;
  HoldSpeakStart(this.isMe);
}

/// Taraf qo‘yib yuborildi — yozuv to‘xtaydi, tarjima boshlanadi.
class StopSpeaking extends JonliAction {}

class SwapLanguages extends JonliAction {}

class OpenVoiceSettings extends JonliAction {}

class OpenHistory extends JonliAction {}

class OpenCameraTranslate extends JonliAction {}

class SelectMyLanguage extends JonliAction {
  final LanguageOption language;
  SelectMyLanguage(this.language);
}

class SelectOtherLanguage extends JonliAction {
  final LanguageOption language;
  SelectOtherLanguage(this.language);
}

class ReloadLiveLanguages extends JonliAction {}

class RetryTurn extends JonliAction {
  final String clientTurnId;
  RetryTurn(this.clientTurnId);
}

class CopyTurnText extends JonliAction {
  final String text;
  CopyTurnText(this.text);
}

class OpenJonliPlans extends JonliAction {}
