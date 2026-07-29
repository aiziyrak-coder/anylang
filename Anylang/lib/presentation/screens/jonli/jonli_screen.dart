import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
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

  static const double _speechLevel = 0.07;
  static const int _silenceMsNeeded = 1800;
  static const int _minRecordMs = 1200;
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
    state.pauseOnLeaveHandler = _pauseLiveSession;
    state.ttsVoice.value = SessionStore.jonliTtsVoice();
    state.ttsSpeed.value = SessionStore.jonliTtsSpeed();
    if (Get.isRegistered<VoicePlayerService>()) {
      Get.find<VoicePlayerService>().setPlaybackRate(state.ttsSpeed.value);
    }
    // Sessiya Start/Camera/History da ochiladi — tab peek tezlashadi.
    _loadLiveLanguages();
  }

  Future<void> _pauseLiveSession() async {
    if (!state.conversationActive.value && state.sessionId.value == null) {
      return;
    }
    _stopSilenceWatch();
    state.conversationActive.value = false;
    state.busy.value = false;
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) {
      await recorder.cancel();
    }
  }

  Future<void> _loadLiveLanguages() async {
    state.liveLanguagesLoadFailed.value = false;
    final result = await Get.find<LiveRepository>().languages();
    if (result.errorOrNull != null) {
      state.liveLanguagesLoadFailed.value = true;
      showAppError(result.errorOrNull);
      return;
    }
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
      state.liveLanguagesLoadFailed.value = true;
      showAppWarning('jonli_languages_failed'.tr);
      codes.addAll(const ['uz', 'en', 'ru', 'de', 'ja', 'zh', 'tr']);
    } else {
      state.liveLanguagesLoadFailed.value = false;
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
    if (identical(state.pauseOnLeaveHandler, _pauseLiveSession)) {
      state.pauseOnLeaveHandler = null;
    }
    _stopSilenceWatch();
    _conversationGen++;
    state.conversationActive.value = false;
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) {
      unawaited(recorder.cancel());
    }
    final id = state.sessionId.value;
    if (id != null) {
      unawaited(
        Get.find<LiveRepository>().endSession(id).then(
          (_) {},
          onError: (Object e, StackTrace st) {
            debugPrint('JonliScreen.endSession failed: $e\n$st');
          },
        ),
      );
      state.sessionId.value = null;
    }
    super.dispose();
  }

  bool _isPremiumRequired(Object? err) {
    final code = AuthValidators.apiErrorCode(err);
    if (code == 'SUBSCRIPTION_REQUIRED' ||
        code == 'PREMIUM_REQUIRED' ||
        code == 'JONLI_PREMIUM_REQUIRED') {
      return true;
    }
    return false;
  }

  Future<void> _offerPlans() async {
    state.needsPremium.value = true;
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
      state.needsPremium.value = false;
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
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!player.isPlaying.value) return;
    if (gen != _conversationGen || !state.conversationActive.value) return;

    final done = Completer<void>();
    late final Worker worker;
    worker = ever<bool>(player.isPlaying, (playing) {
      if (!playing && !done.isCompleted) {
        done.complete();
      }
    });

    try {
      await Future.any<void>([
        done.future,
        Future<void>.delayed(max),
        Future<void>(() async {
          while (gen == _conversationGen &&
              state.conversationActive.value &&
              !done.isCompleted) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          if (!done.isCompleted) done.complete();
        }),
      ]);
    } finally {
      worker.dispose();
    }
  }

  Future<void> _continueConversationAfter({
    required bool justSpokeIsMe,
    required bool hadSpeech,
    required int gen,
  }) async {
    if (gen != _conversationGen || !state.conversationActive.value) return;
    if (!hadSpeech) {
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

  Future<void> _uploadTurn({
    required String turnId,
    required bool isMe,
    required String filePath,
    required bool advanceConversation,
    required int gen,
  }) async {
    final sessionId = state.sessionId.value;
    if (sessionId == null) {
      showAppError('jonli_session_failed'.tr);
      return;
    }

    _upsertTurn(
      JonliTranscriptEntry(
        clientTurnId: turnId,
        isMe: isMe,
        original: '',
        translated: '',
        at: DateTime.now(),
        pending: true,
        audioPath: filePath,
      ),
    );

    state.busy.value = true;
    var translatedOk = false;
    try {
      final result = await Get.find<LiveRepository>().createTurn(
        sessionId: sessionId,
        filePath: filePath,
        speaker: isMe ? 'me' : 'other',
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
            audioPath: filePath,
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
      _upsertTurn(
        JonliTranscriptEntry(
          id: (map['id'] as num?)?.toInt(),
          clientTurnId: turnId,
          isMe: isMe,
          original: original,
          translated: translated,
          at: at,
          audioPath: filePath,
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

    final energy = recorded.samples.isEmpty
        ? 0.0
        : recorded.samples.reduce((a, b) => a + b) / recorded.samples.length;
    if (energy < 0.035 || recorded.duration.inMilliseconds < 600) {
      if (clientTurnId != null) {
        state.turns.removeWhere((t) => t.clientTurnId == clientTurnId);
      }
      showAppMessage('jonli_speak_louder'.tr);
      if (advanceConversation && state.conversationActive.value) {
        await _continueConversationAfter(
          justSpokeIsMe: isMe,
          hadSpeech: false,
          gen: gen,
        );
      }
      return;
    }

    final turnId = clientTurnId ??
        't${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}';
    await _uploadTurn(
      turnId: turnId,
      isMe: isMe,
      filePath: recorded.path,
      advanceConversation: advanceConversation,
      gen: gen,
    );
  }

  Future<void> _retryTurn(String clientTurnId) async {
    final i = state.turns.indexWhere((t) => t.clientTurnId == clientTurnId);
    if (i < 0) return;
    final entry = state.turns[i];
    final path = entry.audioPath;
    if (path == null || path.isEmpty) return;
    if (state.busy.value) return;
    await _ensureSession();
    if (state.sessionId.value == null) return;
    await _uploadTurn(
      turnId: clientTurnId,
      isMe: entry.isMe,
      filePath: path,
      advanceConversation: false,
      gen: _conversationGen,
    );
  }

  Future<void> _runCameraTranslate() async {
    if (state.busy.value) return;
    if (state.conversationActive.value) {
      await _stopConversation(discardRecording: true);
    }
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
          await _finishCurrentUtterance();
          return;
        }
        state.nextIsMe.value = !state.nextIsMe.value;
        if (state.conversationActive.value) {
          await _beginSpeaking(state.nextIsMe.value);
        }
      case StopSpeaking _:
        if (state.conversationActive.value) {
          await _finishCurrentUtterance();
          return;
        }
        await _processStopSpeaking(advanceConversation: false);
      case SwapLanguages _:
        final my = state.myLanguage.value;
        state.myLanguage.value = state.otherLanguage.value;
        state.otherLanguage.value = my;
        await _resetSession();
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
        await _ensureSession();
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
      case ReloadLiveLanguages _:
        await _loadLiveLanguages();
      case RetryTurn a:
        await _retryTurn(a.clientTurnId);
      case CopyTurnText a:
        await Clipboard.setData(ClipboardData(text: a.text));
        showAppMessage('jonli_copied'.tr);
      case OpenJonliPlans _:
        await navigate(SubscriptionScreen());
        state.needsPremium.value = false;
    }
  }
}
