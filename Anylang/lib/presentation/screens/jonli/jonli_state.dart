import 'package:get/get.dart';

import '../select_language/select_language_option.dart';
import 'jonli_transcript_entry.dart';

/// Hold-to-talk holati: kimning mikrofoni ochiq.
enum JonliMode { idle, me, other }

/// Jonli ekranining reaktiv holati (faqat qiymatlar — logika Screen da).
class JonliState extends GetxController {
  final Rx<JonliMode> mode = JonliMode.idle.obs;
  final Rx<LanguageOption> myLanguage = languageOptions[0].obs;
  final Rx<LanguageOption> otherLanguage = languageOptions[1].obs;

  final RxnInt sessionId = RxnInt();
  final RxBool busy = false.obs;
  final RxBool needsPremium = false.obs;

  /// Tab (IndexedStack) almashganda sessiyani to‘xtatish.
  Future<void> Function()? pauseOnLeaveHandler;

  final RxString ttsVoice = 'female'.obs;
  final RxDouble ttsSpeed = 1.0.obs;
  final RxList<JonliTranscriptEntry> turns = <JonliTranscriptEntry>[].obs;

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

  bool get isRecording => mode.value != JonliMode.idle;
}
