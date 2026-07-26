import 'package:get/get.dart';

import '../select_language/select_language_option.dart';
import 'jonli_transcript_entry.dart';

/// Jonli muloqot o'rta body holati.
enum JonliMode {
  idle,
  me,
  other,
}

class JonliState extends GetxController {
  Rx<JonliMode> mode = JonliMode.idle.obs;
  Rx<LanguageOption> myLanguage = languageOptions[0].obs;
  Rx<LanguageOption> otherLanguage = languageOptions[1].obs;

  final RxnInt sessionId = RxnInt();
  final RxString lastOriginal = ''.obs;
  final RxString lastTranslated = ''.obs;
  final RxBool busy = false.obs;

  /// Conversation Mode — navbat bilan avtomatik mikrofon.
  final RxBool conversationActive = false.obs;
  /// Keyingi (yoki joriy) navbat — sizmi.
  final RxBool nextIsMe = true.obs;

  /// Tab o‘zgarganda (IndexedStack) jonli sessiyani to‘xtatish.
  Future<void> Function()? pauseOnLeaveHandler;

  /// AI ovoz: female | male
  final RxString ttsVoice = 'female'.obs;
  /// AI ovoz tezligi 0.5–2.0
  final RxDouble ttsSpeed = 1.0.obs;

  /// Sessiya gaplari — har biri vaqt + asl + tarjima.
  final RxList<JonliTranscriptEntry> turns = <JonliTranscriptEntry>[].obs;

  /// Server Live API tillari (langCode).
  final RxSet<String> liveLangCodes = <String>{
    'uz',
    'en',
    'ru',
    'de',
    'ja',
    'zh',
    'tr',
  }.obs;
  final RxBool liveLanguagesLoadFailed = false.obs;
}
