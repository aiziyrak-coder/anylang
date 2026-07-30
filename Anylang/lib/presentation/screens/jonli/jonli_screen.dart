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
import '../../../data/network/profile_repository.dart';
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

/// Jonli: hold-to-talk og‘zaki tarjima.
///
/// Oqim: tarafni bosib turish → yozish → qo‘yib yuborish → tarjima (+ TTS).
/// Navbat avtomatik emas — kim gapirsa, o‘sha taraf bosiladi.
class JonliScreen extends Screen<JonliState, void> {
  JonliScreen() : super(mobileContent: JonliContent());

  static const int _maxHoldMs = 45000;
  static const double _minEnergy = 0.035;
  static const int _minDurationMs = 600;

  int _turnSeq = 0;
  String? _pendingClientTurnId;
  Timer? _maxHoldTimer;

  bool _stopping = false;
  bool _starting = false;
  /// Barmoq hali bosib turilganmi (async start paytida bekor qilish uchun).
  bool _holdDesired = false;
  /// TTS kutishni bekor qilish (dispose / reset).
  int _playbackGen = 0;

  @override
  void initState(void payload) {
    state.pauseOnLeaveHandler = _pauseLiveSession;
    state.ttsVoice.value = SessionStore.jonliTtsVoice();
    state.ttsSpeed.value = SessionStore.jonliTtsSpeed();
    if (Get.isRegistered<VoicePlayerService>()) {
      Get.find<VoicePlayerService>().setPlaybackRate(state.ttsSpeed.value);
    }
    _loadLiveLanguages();
  }

  @override
  void dispose() {
    if (identical(state.pauseOnLeaveHandler, _pauseLiveSession)) {
      state.pauseOnLeaveHandler = null;
    }
    _invalidatePlayback();
    _stopMaxHoldWatch();
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

  // ─── Lifecycle helpers ─────────────────────────────────────────────

  void _invalidatePlayback() => _playbackGen++;

  Future<void> _pauseLiveSession() async {
    if (!state.isRecording && state.sessionId.value == null) return;
    _holdDesired = false;
    _stopMaxHoldWatch();
    state.busy.value = false;
    state.mode.value = JonliMode.idle;
    _dropPendingTurn();
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) await recorder.cancel();
  }

  Future<void> _abortRecording({required bool discard}) async {
    _invalidatePlayback();
    _holdDesired = false;
    _stopMaxHoldWatch();
    final recorder = Get.find<VoiceRecorderService>();
    if (recorder.isRecording.value) {
      if (discard) {
        await recorder.cancel();
        _dropPendingTurn();
        state.mode.value = JonliMode.idle;
      } else {
        await _finishHold();
      }
    } else {
      state.mode.value = JonliMode.idle;
    }
  }

  void _dropPendingTurn() {
    final pending = _pendingClientTurnId;
    _pendingClientTurnId = null;
    if (pending != null) {
      state.turns.removeWhere((t) => t.clientTurnId == pending);
    }
  }

  // ─── Session / languages ───────────────────────────────────────────

  bool _isPremiumRequired(Object? err) {
    final code = AuthValidators.apiErrorCode(err);
    return code == 'SUBSCRIPTION_REQUIRED' ||
        code == 'PREMIUM_REQUIRED' ||
        code == 'JONLI_PREMIUM_REQUIRED';
  }

  bool _isSpeechNotRecognized(Object? err) {
    final code = AuthValidators.apiErrorCode(err);
    if (code == 'SPEECH_NOT_RECOGNIZED' ||
        code == 'NO_SPEECH_DETECTED' ||
        code == 'STT_FAILED') {
      return true;
    }
    final raw = err?.toString().toLowerCase() ?? '';
    return raw.contains('aniqlol') || raw.contains('nutq topilmadi');
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
      return;
    }
    final err = result.errorOrNull;
    if (err == null) return;
    if (_isPremiumRequired(err)) {
      await _offerPlans();
    } else {
      showAppError(err);
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
    await _abortRecording(discard: true);
    final old = state.sessionId.value;
    if (old != null) {
      await Get.find<LiveRepository>().endSession(old);
    }
    state.sessionId.value = null;
    state.turns.clear();
    await _ensureSession();
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

  Future<void> _persistVoice({
    required String voice,
    required double speed,
  }) async {
    final v = voice == 'male' ? 'male' : 'female';
    final s = speed.clamp(0.5, 2.0);
    state.ttsVoice.value = v;
    state.ttsSpeed.value = s;
    await SessionStore.setJonliTtsVoice(v);
    await SessionStore.setJonliTtsSpeed(s);
    if (Get.isRegistered<VoicePlayerService>()) {
      await Get.find<VoicePlayerService>().setPlaybackRate(s);
    }
  }

  // ─── Hold-to-talk ──────────────────────────────────────────────────

  void _stopMaxHoldWatch() {
    _maxHoldTimer?.cancel();
    _maxHoldTimer = null;
  }

  void _startMaxHoldWatch() {
    _stopMaxHoldWatch();
    final recorder = Get.find<VoiceRecorderService>();
    _maxHoldTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!state.isRecording || _stopping) return;
      if (!recorder.isRecording.value) return;
      if (recorder.elapsed.inMilliseconds >= _maxHoldMs) {
        unawaited(_finishHold());
      }
    });
  }

  Future<void> _finishHold() async {
    if (_stopping) return;
    final recorder = Get.find<VoiceRecorderService>();
    if (!state.isRecording && !recorder.isRecording.value) return;

    _stopping = true;
    _stopMaxHoldWatch();
    try {
      await _processRelease();
    } finally {
      _stopping = false;
    }
  }

  Future<void> _beginHold(bool isMe) async {
    if (_starting || _stopping || state.busy.value || state.isRecording) {
      return;
    }
    _starting = true;
    try {
      await _ensureSession();
      if (!_holdDesired || state.sessionId.value == null) return;

      if (Get.isRegistered<VoicePlayerService>()) {
        final player = Get.find<VoicePlayerService>();
        if (player.isPlaying.value) await player.stop(save: true);
      }
      if (!_holdDesired) return;

      final ok = await Get.find<VoiceRecorderService>().start();
      if (!ok) {
        showAppMessage('mic_permission_denied'.tr);
        return;
      }
      if (!_holdDesired) {
        await Get.find<VoiceRecorderService>().cancel();
        return;
      }

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
      _startMaxHoldWatch();
    } finally {
      _starting = false;
      if (!_holdDesired &&
          state.isRecording &&
          Get.find<VoiceRecorderService>().isRecording.value) {
        unawaited(_finishHold());
      }
    }
  }

  Future<void> _processRelease() async {
    final recorder = Get.find<VoiceRecorderService>();
    if (!state.isRecording && !recorder.isRecording.value) return;

    final isMe = state.mode.value != JonliMode.other;
    final gen = _playbackGen;
    _stopMaxHoldWatch();

    final recorded = await recorder.stop();
    state.mode.value = JonliMode.idle;
    final clientTurnId = _pendingClientTurnId;
    _pendingClientTurnId = null;

    if (recorded == null) {
      if (clientTurnId != null) {
        state.turns.removeWhere((t) => t.clientTurnId == clientTurnId);
      }
      return;
    }

    final energy = recorded.samples.isEmpty
        ? 0.0
        : recorded.samples.reduce((a, b) => a + b) / recorded.samples.length;
    if (energy < _minEnergy ||
        recorded.duration.inMilliseconds < _minDurationMs) {
      if (clientTurnId != null) {
        state.turns.removeWhere((t) => t.clientTurnId == clientTurnId);
      }
      showAppMessage('jonli_speak_louder'.tr);
      return;
    }

    await _uploadTurn(
      turnId: clientTurnId ??
          't${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}',
      isMe: isMe,
      filePath: recorded.path,
      gen: gen,
    );
  }

  Future<void> _uploadTurn({
    required String turnId,
    required bool isMe,
    required String filePath,
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
        final err = result.errorOrNull ?? 'jonli_translate_failed'.tr;
        if (_isPremiumRequired(err)) {
          await _offerPlans();
          return;
        }
        if (_isSpeechNotRecognized(err)) {
          state.turns.removeWhere((t) => t.clientTurnId == turnId);
          showAppMessage('jonli_not_recognized'.tr);
          return;
        }
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
        showAppError(err);
        return;
      }

      _upsertTurn(
        JonliTranscriptEntry(
          id: (map['id'] as num?)?.toInt(),
          clientTurnId: turnId,
          isMe: isMe,
          original: map['text_original']?.toString() ?? '',
          translated: map['text_translated']?.toString() ?? '',
          at: parseApiDateTime(map['created_at']) ?? DateTime.now(),
          audioPath: filePath,
        ),
      );

      // Matn chiqishi bilan hold yana ochiladi; TTS fonda.
      state.busy.value = false;

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
  }

  Future<void> _waitPlaybackDone({
    required int gen,
    Duration max = const Duration(seconds: 10),
  }) async {
    if (!Get.isRegistered<VoicePlayerService>()) return;
    final player = Get.find<VoicePlayerService>();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!player.isPlaying.value || gen != _playbackGen) return;

    final done = Completer<void>();
    late final Worker worker;
    worker = ever<bool>(player.isPlaying, (playing) {
      if (!playing && !done.isCompleted) done.complete();
    });
    try {
      await Future.any<void>([done.future, Future<void>.delayed(max)]);
    } finally {
      worker.dispose();
    }
  }

  Future<void> _retryTurn(String clientTurnId) async {
    final i = state.turns.indexWhere((t) => t.clientTurnId == clientTurnId);
    if (i < 0 || state.busy.value) return;
    final entry = state.turns[i];
    final path = entry.audioPath;
    if (path == null || path.isEmpty) return;
    await _ensureSession();
    if (state.sessionId.value == null) return;
    await _uploadTurn(
      turnId: clientTurnId,
      isMe: entry.isMe,
      filePath: path,
      gen: _playbackGen,
    );
  }

  Future<void> _runCameraTranslate() async {
    if (state.busy.value) return;
    if (state.isRecording) await _abortRecording(discard: true);
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
      _upsertTurn(
        JonliTranscriptEntry(
          id: (map['turn_id'] as num?)?.toInt(),
          clientTurnId: map['client_turn_id']?.toString() ?? clientTurnId,
          isMe: true,
          original: map['text_original']?.toString() ?? '',
          translated: map['text_translated']?.toString() ?? '',
          at: parseApiDateTime(map['created_at']) ?? DateTime.now(),
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
      case HoldSpeakStart a:
        if (state.busy.value || state.isRecording) return;
        _holdDesired = true;
        await _beginHold(a.isMe);
      case StopSpeaking _:
        _holdDesired = false;
        if (_starting) return;
        await _finishHold();
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
        await _persistVoice(voice: picked.voice, speed: picked.speed);
      case OpenHistory _:
        await _ensureSession();
        await showJonliHistoryBottomSheet(context);
      case OpenCameraTranslate _:
        await _runCameraTranslate();
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
        final me = await Get.find<ProfileRepository>().getMe();
        final map = asMap(me.dataOrNull);
        final sub = map?['subscription'];
        final active = sub is Map &&
            (sub['is_active'] == true || sub['status']?.toString() == 'active');
        if (active) state.needsPremium.value = false;
    }
  }
}
