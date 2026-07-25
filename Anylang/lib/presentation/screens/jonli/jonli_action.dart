import '../../utils/screen_options/my_action.dart';
import '../select_language/select_language_option.dart';

/// Faqat Jonli muloqot ekraniga xos action'lar.
class JonliAction extends MyAction {}

/// Tugma bosib turilganda — gapirish boshlandi. `isMe` true → siz, false → suhbatdosh.
class StartSpeaking extends JonliAction {
  final bool isMe;
  StartSpeaking(this.isMe);
}

/// Tugma qo'yib yuborilganda — gapirish tugadi (idle).
class StopSpeaking extends JonliAction {}

/// Conversation Mode: navbat bilan suhbat (yoqish/o‘chirish).
class ToggleConversation extends JonliAction {}

/// Navbatni qo‘lda almashtirish (🔄).
class SwitchConversationTurn extends JonliAction {}

/// Tillarni almashtirish.
class SwapLanguages extends JonliAction {}

/// Temani almashtirish (quyosh tugmasi).
class ToggleTheme extends JonliAction {}

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
