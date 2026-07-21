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

/// Tillarni almashtirish.
class SwapLanguages extends JonliAction {}

/// Temani almashtirish (quyosh tugmasi).
class ToggleTheme extends JonliAction {}

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
