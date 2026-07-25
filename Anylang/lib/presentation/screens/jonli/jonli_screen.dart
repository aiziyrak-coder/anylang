import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/audio/voice_player_service.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/live_repository.dart';
import '../../modal/image_picker.dart';
import '../../modal/jonli_history_bottom_sheet.dart';
import '../../modal/jonli_voice_settings_bottom_sheet.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../select_language/select_language_option.dart';
import '../subscription/subscription_screen.dart';
import 'jonli_action.dart';
import 'jonli_content.dart';
import 'jonli_state.dart';
import 'jonli_transcript_entry.dart';

class JonliScreen extends Screen<JonliState, void> {
  JonliScreen() : super(mobileContent: JonliContent());

  static const double _speechLevel = 0.14;
  static const int _silenceMsNeeded = 1100;
  static const int _minRecordMs = 900;
  static const int _maxTurnMs = 45000;

  int _turnSeq = 0;
  String? _pendingClientTurnId;
  Timer? _silenceTimer;
  bool _heardSpeech = false;
  int _silenceAccumMs = 0;
  bool _stoppingTurn = false;
  int _conversationGen = 0;

  @override
  void initState(void payload) {
    state.ttsVoice.value = SessionStore.jonliTtsVoice();
    state.ttsSpeed.value = SessionStore.jonliTtsSpeed();
    if (Get.isRegistered<VoicePlayerService>()) {
      Get.find<VoicePlayerService>().setPlaybackRate(state.ttsSpeed.value);
    }
    _loadLiveLanguages();
    _ensureSession();
  }

  Future<void> _loadLiveLanguages() async {
    final result = await Get.find<LiveRepository>().languages();
    final data = result.dataOrNull;
    final codes = <String>{};
    if (data is Map) {
      final list = data['languages'];
      if (list is List) {
        for (final item in list) {
          if (item is Map && item['code'] != null) {
            codes.add(item['code'].toString());
          }
        }
      }
    }
    if (codes.isEmpty) {
      codes.addAll(const ['uz', 'en', 'ru', 'de', 'ja', 'zh', 'tr']);
    }
    state.liveLangCodes.assignAll(codes);
    if (!codes.contains(state.myLanguage.value.langCode)) {
      state.myLanguage.value = languageOptions.firstWhere(
        (o) => codes.contains(o.langCode),
        orElse: () => languageOptions.first,
      );
    }
    if (!codes.contains(state.otherLanguage.value.langCode)) {
      state.otherLanguage.value = languageOptions.firstWhere(
        (o) =>
            codes.contains(o.langCode) &&
            o.langCode != state.myLanguage.value.langCode,
        orElse: () => languageOptions.first,
      );
    }
  }

  @override
  void dispose() {
    _stopSilenceWatch();
    _conversationGen++;
    state.conversationActive.value = false;
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) {
      recorder.cancel();
    }
    final id = state.sessionId.value;
    if (id != null) {
      Get.find<LiveRepository>().endSession(id);
    }
  }

  bool _isPremiumRequired(Object? err) {
    final text = err?.toString().toLowerCase() ?? '';
    return text.contains('premium') ||
        text.contains('subscription') ||
        text.contains('jonli muloqot uchun') ||
        text.contains('подписк') ||
        text.contains('тариф');
  }

  Future<void> _offerPlans() async {
    showAppMessage('jonli_premium_required'.tr);
    await navigate(SubscriptionScreen());
  }

  Future<void> _ensureSession() async {
    if (state.sessionId.value != null) return;
    final result = await Get.find<LiveRepository>().startSession(
      myLanguage: state.myLanguage.value.langCode,
      otherLanguage: state.otherLanguage.value.langCode,
    );
    final map = asMap(result.dataOrNull);
    final id = (map?['id'] as num?)?.toInt();
    if (id != null) {
      state.sessionId.value = id;
      await _loadTurns(id);
    } else if (result.errorOrNull != null) {
      final err = result.errorOrNull;
      if (_isPremiumRequired(err)) {
        await _offerPlans();
      } else {
        showAppError(err);
      }
    }
  }

  Future<void> _loadTurns(int sessionId) async {
    final result = await Get.find<LiveRepository>().turns(sessionId);
    final map = asMap(result.dataOrNull);
    final items = map?['items'];
    if (items is! List) return;
    final parsed = <JonliTranscriptEntry>[];
    for (final raw in items) {
      final entry = _entryFromMap(asMap(raw));
      if (entry != null) parsed.add(entry);
    }
    parsed.sort((a, b) => a.at.compareTo(b.at));
    state.turns.assignAll(parsed);
    if (parsed.isNotEmpty) {
      final last = parsed.last;
      state.lastOriginal.value = last.original;
      state.lastTranslated.value = last.translated;
    }
  }

  JonliTranscriptEntry? _entryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final original = map['text_original']?.toString() ?? '';
    final translated = map['text_translated']?.toString() ?? '';
    if (original.isEmpty && translated.isEmpty) return null;
    final speaker = map['speaker']?.toString() ?? 'me';
    final at = parseApiDateTime(map['created_at']) ?? DateTime.now();
    return JonliTranscriptEntry(
      id: (map['id'] as num?)?.toInt(),
      clientTurnId:
          map['client_turn_id']?.toString() ?? 't${at.microsecondsSinceEpoch}',
      isMe: speaker != 'other',
      original: original,
      translated: translated,
      at: at,
    );
  }

  void _upsertTurn(JonliTranscriptEntry entry) {
    final i =
        state.turns.indexWhere((t) => t.clientTurnId == entry.clientTurnId);
    if (i >= 0) {
      state.turns[i] = entry;
      state.turns.refresh();
    } else {
      state.turns.add(entry);
    }
  }

  Future<void> _resetSession() async {
    await _stopConversation(discardRecording: true);
    final old = state.sessionId.value;
    if (old != null) {
      await Get.find<LiveRepository>().endSession(old);
    }
    state.sessionId.value = null;
    state.turns.clear();
    state.lastOriginal.value = '';
    state.lastTranslated.value = '';
    await _ensureSession();
  }

  void _stopSilenceWatch() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _heardSpeech = false;
    _silenceAccumMs = 0;
  }

  void _startSilenceWatch() {
    _stopSilenceWatch();
    _heardSpeech = false;
    _silenceAccumMs = 0;
    final recorder = Get.find<VoiceRecorderService>();
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!state.conversationActive.value ||
          state.mode.value == JonliMode.idle ||
          _stoppingTurn) {
        return;
      }
      if (!recorder.isRecording.value) return;

      final level = recorder.level.value;
      final elapsedMs = recorder.elapsed.inMilliseconds;

      if (elapsedMs >= _maxTurnMs) {
        unawaited(_finishCurrentUtterance());
        return;
      }

      if (level >= _speechLevel) {
        _heardSpeech = true;
        _silenceAccumMs = 0;
        return;
      }

      if (!_heardSpeech) return;
      _silenceAccumMs += 100;
      if (_silenceAccumMs >= _silenceMsNeeded && elapsedMs >= _minRecordMs) {
        unawaited(_finishCurrentUtterance());
      }
    });
  }

  Future<void> _finishCurrentUtterance() async {
    if (_stoppingTurn) return;
    if (state.mode.value == JonliMode.idle) return;
    _stoppingTurn = true;
    _stopSilenceWatch();
    try {
      await _processStopSpeaking(advanceConversation: true);
    } finally {
      _stoppingTurn = false;
    }
  }

  Future<void> _beginSpeaking(bool isMe) async {
    await _ensureSession();
    if (state.sessionId.value == null) {
      state.conversationActive.value = false;
      return;
    }
    if (Get.isRegistered<VoicePlayerService>()) {
      final player = Get.find<VoicePlayerService>();
      if (player.isPlaying.value) await player.stop(save: true);
    }
    final ok = await Get.find<VoiceRecorderService>().start();
    if (!ok) {
      showAppMessage('mic_permission_denied'.tr);
      state.conversationActive.value = false;
      return;
    }
    state.nextIsMe.value = isMe;
    state.mode.value = isMe ? JonliMode.me : JonliMode.other;
    final clientTurnId =
        't${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}';
    _pendingClientTurnId = clientTurnId;
    _upsertTurn(
      JonliTranscriptEntry(
        clientTurnId: clientTurnId,
        isMe: isMe,
        original: '',
        translated: '',
        at: DateTime.now(),
        pending: true,
      ),
    );
    if (state.conversationActive.value) {
      _startSilenceWatch();
    }
  }

  Future<void> _waitPlaybackDone({
    required int gen,
    Duration max = const Duration(seconds: 10),
  }) async {
    if (!Get.isRegistered<VoicePlayerService>()) return;
    final player = Get.find<VoicePlayerService>();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final deadline = DateTime.now().add(max);
    while (player.isPlaying.value &&
        DateTime.now().isBefore(deadline) &&
        gen == _conversationGen &&
        state.conversationActive.value) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _continueConversationAfter({
    required bool justSpokeIsMe,
    required bool hadSpeech,
    required int gen,
  }) async {
    if (gen != _conversationGen || !state.conversationActive.value) return;
    if (!hadSpeech) {
      // Qayta tinglash — xuddi shu navbat.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (gen != _conversationGen || !state.conversationActive.value) return;
      await _beginSpeaking(justSpokeIsMe);
      return;
    }
    final nextIsMe = !justSpokeIsMe;
    state.nextIsMe.value = nextIsMe;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (gen != _conversationGen || !state.conversationActive.value) return;
    await _beginSpeaking(nextIsMe);
  }

  Future<void> _stopConversation({bool discardRecording = false}) async {
    _conversationGen++;
    _stopSilenceWatch();
    state.conversationActive.value = false;
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) {
      if (discardRecording) {
        await recorder.cancel();
        final pending = _pendingClientTurnId;
        _pendingClientTurnId = null;
        if (pending != null) {
          state.turns.removeWhere((t) => t.clientTurnId == pending);
        }
        state.mode.value = JonliMode.idle;
      } else {
        await _processStopSpeaking(advanceConversation: false);
      }
    } else {
      state.mode.value = JonliMode.idle;
    }
  }

  Future<void> _processStopSpeaking({required bool advanceConversation}) async {
    if (state.mode.value == JonliMode.idle &&
        !Get.find<VoiceRecorderService>().isRecording.value) {
      return;
    }
    final speaker = state.mode.value == JonliMode.other ? 'other' : 'me';
    final isMe = speaker == 'me';
    final gen = _conversationGen;
    _stopSilenceWatch();

    final recorded = await Get.find<VoiceRecorderService>().stop();
    state.mode.value = JonliMode.idle;
    final clientTurnId = _pendingClientTurnId;
    _pendingClientTurnId = null;

    if (recorded == null) {
      if (clientTurnId != null) {
        state.turns.removeWhere((t) => t.clientTurnId == clientTurnId);
      }
      if (advanceConversation && state.conversationActive.value) {
        await _continueConversationAfter(
          justSpokeIsMe: isMe,
          hadSpeech: false,
          gen: gen,
        );
      }
      return;
    }

    final sessionId = state.sessionId.value;
    if (sessionId == null) {
      showAppError('jonli_session_failed'.tr);
      return;
    }

    final turnId =
        clientTurnId ?? 't${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}';
    _upsertTurn(
      JonliTranscriptEntry(
        clientTurnId: turnId,
        isMe: isMe,
        original: '',
        translated: '',
        at: DateTime.now(),
        pending: true,
      ),
    );

    state.busy.value = true;
    var translatedOk = false;
    try {
      final result = await Get.find<LiveRepository>().createTurn(
        sessionId: sessionId,
        filePath: recorded.path,
        speaker: speaker,
        clientTurnId: turnId,
        ttsVoice: state.ttsVoice.value,
        ttsSpeed: state.ttsSpeed.value,
      );
      final map = asMap(result.dataOrNull);
      if (map == null) {
        _upsertTurn(
          JonliTranscriptEntry(
            clientTurnId: turnId,
            isMe: isMe,
            original: '',
            translated: '',
            at: DateTime.now(),
            pending: false,
            failed: true,
          ),
        );
        final err = result.errorOrNull ?? 'jonli_translate_failed'.tr;
        if (_isPremiumRequired(err)) {
          state.conversationActive.value = false;
          await _offerPlans();
        } else {
          showAppError(err);
        }
        if (advanceConversation && state.conversationActive.value) {
          await _continueConversationAfter(
            justSpokeIsMe: isMe,
            hadSpeech: false,
            gen: gen,
          );
        }
        return;
      }

      final original = map['text_original']?.toString() ?? '';
      final translated = map['text_translated']?.toString() ?? '';
      final at = parseApiDateTime(map['created_at']) ?? DateTime.now();
      state.lastOriginal.value = original;
      state.lastTranslated.value = translated;
      _upsertTurn(
        JonliTranscriptEntry(
          id: (map['id'] as num?)?.toInt(),
          clientTurnId: turnId,
          isMe: isMe,
          original: original,
          translated: translated,
          at: at,
        ),
      );
      translatedOk = original.isNotEmpty || translated.isNotEmpty;

      final audioUrl = map['audio_url']?.toString() ??
          map['tts_url']?.toString() ??
          map['audio_tts_url']?.toString() ??
          '';
      if (audioUrl.isNotEmpty && Get.isRegistered<VoicePlayerService>()) {
        await Get.find<VoicePlayerService>().toggle(
          id: 'jonli_$sessionId',
          path: audioUrl,
          duration: Duration(
            seconds: (map['tts_duration_seconds'] as num?)?.toInt() ?? 3,
          ),
        );
        await _waitPlaybackDone(gen: gen);
      }
    } finally {
      state.busy.value = false;
    }

    if (advanceConversation && state.conversationActive.value) {
      await _continueConversationAfter(
        justSpokeIsMe: isMe,
        hadSpeech: translatedOk,
        gen: gen,
      );
    }
  }

  Future<void> _runCameraTranslate() async {
    if (state.busy.value) return;
    await _ensureSession();
    if (state.sessionId.value == null) return;

    final file = await pickImage(context, source: ImageSource.camera);
    if (file == null) return;

    final clientTurnId =
        'ocr${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}';
    _upsertTurn(
      JonliTranscriptEntry(
        clientTurnId: clientTurnId,
        isMe: true,
        original: '',
        translated: '',
        at: DateTime.now(),
        pending: true,
        fromCamera: true,
      ),
    );
    state.busy.value = true;
    try {
      final result = await Get.find<LiveRepository>().ocrTranslate(
        filePath: file.path,
        targetLanguage: state.myLanguage.value.langCode,
        sourceLanguage: state.otherLanguage.value.langCode,
        sessionId: state.sessionId.value,
        clientTurnId: clientTurnId,
        ttsVoice: state.ttsVoice.value,
        ttsSpeed: state.ttsSpeed.value,
      );
      final map = asMap(result.dataOrNull);
      if (map == null) {
        _upsertTurn(
          JonliTranscriptEntry(
            clientTurnId: clientTurnId,
            isMe: true,
            original: '',
            translated: '',
            at: DateTime.now(),
            pending: false,
            failed: true,
            fromCamera: true,
          ),
        );
        final err = result.errorOrNull ?? 'jonli_ocr_failed'.tr;
        if (_isPremiumRequired(err)) {
          await _offerPlans();
        } else {
          showAppError(err);
        }
        return;
      }
      final original = map['text_original']?.toString() ?? '';
      final translated = map['text_translated']?.toString() ?? '';
      final at = parseApiDateTime(map['created_at']) ?? DateTime.now();
      state.lastOriginal.value = original;
      state.lastTranslated.value = translated;
      _upsertTurn(
        JonliTranscriptEntry(
          id: (map['turn_id'] as num?)?.toInt(),
          clientTurnId: map['client_turn_id']?.toString() ?? clientTurnId,
          isMe: true,
          original: original,
          translated: translated,
          at: at,
          fromCamera: true,
        ),
      );
      final audioUrl = map['audio_tts_url']?.toString() ?? '';
      if (audioUrl.isNotEmpty && Get.isRegistered<VoicePlayerService>()) {
        final sid = state.sessionId.value ?? 0;
        await Get.find<VoicePlayerService>().toggle(
          id: 'jonli_ocr_$sid',
          path: audioUrl,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      state.busy.value = false;
    }
  }

  @override
  Future<void> actionHandler(JonliState state, MyAction action) async {
    switch (action) {
      case ToggleConversation _:
        if (state.conversationActive.value) {
          await _stopConversation(discardRecording: false);
          return;
        }
        await _ensureSession();
        if (state.sessionId.value == null) return;
        _conversationGen++;
        state.conversationActive.value = true;
        state.nextIsMe.value = true;
        await _beginSpeaking(true);
      case SwitchConversationTurn _:
        if (state.busy.value) return;
        if (state.mode.value != JonliMode.idle) {
          // Joriy gapni yakunlab, navbatni almashtiramiz.
          await _finishCurrentUtterance();
          return;
        }
        state.nextIsMe.value = !state.nextIsMe.value;
        if (state.conversationActive.value) {
          await _beginSpeaking(state.nextIsMe.value);
        }
      case StartSpeaking a:
        // Legacy hold-to-talk — Conversation Mode ichida ham ishlaydi.
        if (state.conversationActive.value) return;
        await _beginSpeaking(a.isMe);
      case StopSpeaking _:
        if (state.conversationActive.value) {
          // Suhbatda: qo‘lda tugatish = gap yakun + tarjima + navbat.
          await _finishCurrentUtterance();
          return;
        }
        await _processStopSpeaking(advanceConversation: false);
      case SwapLanguages _:
        final my = state.myLanguage.value;
        state.myLanguage.value = state.otherLanguage.value;
        state.otherLanguage.value = my;
        await _resetSession();
      case ToggleTheme _:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Get.find<ThemeController>()
            .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      case OpenVoiceSettings _:
        final picked = await showJonliVoiceSettingsBottomSheet(
          context,
          voice: state.ttsVoice.value,
          speed: state.ttsSpeed.value,
        );
        if (picked == null) return;
        final voice = picked.voice == 'male' ? 'male' : 'female';
        final speed = picked.speed.clamp(0.5, 2.0);
        state.ttsVoice.value = voice;
        state.ttsSpeed.value = speed;
        await SessionStore.setJonliTtsVoice(voice);
        await SessionStore.setJonliTtsSpeed(speed);
        if (Get.isRegistered<VoicePlayerService>()) {
          await Get.find<VoicePlayerService>().setPlaybackRate(speed);
        }
      case OpenHistory _:
        await showJonliHistoryBottomSheet(context);
      case OpenCameraTranslate _:
        await _runCameraTranslate();
      case ApplyVoiceSettings a:
        final voice = a.voice == 'male' ? 'male' : 'female';
        final speed = a.speed.clamp(0.5, 2.0);
        state.ttsVoice.value = voice;
        state.ttsSpeed.value = speed;
        await SessionStore.setJonliTtsVoice(voice);
        await SessionStore.setJonliTtsSpeed(speed);
        if (Get.isRegistered<VoicePlayerService>()) {
          await Get.find<VoicePlayerService>().setPlaybackRate(speed);
        }
      case SelectMyLanguage a:
        state.myLanguage.value = a.language;
        await _resetSession();
      case SelectOtherLanguage a:
        state.otherLanguage.value = a.language;
        await _resetSession();
    }
  }
}
