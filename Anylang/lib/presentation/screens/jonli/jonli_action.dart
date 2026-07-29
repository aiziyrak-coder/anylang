import '../../utils/screen_options/my_action.dart';
import '../select_language/select_language_option.dart';

/// Faqat Jonli muloqot ekraniga xos action'lar.
class JonliAction extends MyAction {}

/// Tugma qo'yib yuborilganda — gapirish tugadi (idle).
class StopSpeaking extends JonliAction {}

/// Conversation Mode: navbat bilan suhbat (yoqish/o‘chirish).
class ToggleConversation extends JonliAction {}

/// Navbatni qo‘lda almashtirish.
class SwitchConversationTurn extends JonliAction {}

/// Tillarni almashtirish.
class SwapLanguages extends JonliAction {}

/// AI ovoz sozlamalari (jins + tezlik).
class OpenVoiceSettings extends JonliAction {}

/// Suhbatlar tarixi (bugun + qidiruv + eksport).
class OpenHistory extends JonliAction {}

/// Kamera orqali matn o‘qish + tarjima.
class OpenCameraTranslate extends JonliAction {}

class ApplyVoiceSettings extends JonliAction {
  final String voice; // female | male
  final double speed; // 0.5–2.0
  ApplyVoiceSettings({required this.voice, required this.speed});
}

/// Til belgilash bottom sheet'idan "Mening tilim" uchun tanlangan til qaytganda.
class SelectMyLanguage extends JonliAction {
  final LanguageOption language;
  SelectMyLanguage(this.language);
}

/// Til belgilash bottom sheet'idan "Suhbatdosh" tili uchun tanlangan til qaytganda.
class SelectOtherLanguage extends JonliAction {
  final LanguageOption language;
  SelectOtherLanguage(this.language);
}

/// Live tillar ro‘yxatini qayta yuklash.
class ReloadLiveLanguages extends JonliAction {}

/// Muvaffaqiyatsiz turnni qayta yuborish.
class RetryTurn extends JonliAction {
  final String clientTurnId;
  RetryTurn(this.clientTurnId);
}

/// Turn matnini clipboardga nusxa.
class CopyTurnText extends JonliAction {
  final String text;
  CopyTurnText(this.text);
}

/// Premium paywall — tariflar.
class OpenJonliPlans extends JonliAction {}
