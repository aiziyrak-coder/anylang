import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/audio/voice_player_service.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/core/mappers.dart';
import '../../../data/network/live_repository.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'jonli_action.dart';
import 'jonli_content.dart';
import 'jonli_state.dart';

class JonliScreen extends Screen<JonliState, void> {
  JonliScreen() : super(mobileContent: JonliContent());

  int _turnSeq = 0;

  @override
  void initState(void payload) {
    _ensureSession();
  }

  @override
  void dispose() {
    final id = state.sessionId.value;
    if (id != null) {
      Get.find<LiveRepository>().endSession(id);
    }
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
    } else if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
    }
  }

  @override
  Future<void> actionHandler(JonliState state, MyAction action) async {
    switch (action) {
      case StartSpeaking a:
        await _ensureSession();
        if (state.sessionId.value == null) return;
        final player = Get.find<VoicePlayerService>();
        if (player.isPlaying.value) await player.stop(save: true);
        final ok = await Get.find<VoiceRecorderService>().start();
        if (!ok) {
          showAppMessage('Mikrofon uchun ruxsat berilmadi');
          return;
        }
        state.mode.value = a.isMe ? JonliMode.me : JonliMode.other;
      case StopSpeaking _:
        final speaker = state.mode.value == JonliMode.other ? 'other' : 'me';
        final recorded = await Get.find<VoiceRecorderService>().stop();
        state.mode.value = JonliMode.idle;
        if (recorded == null) return;
        final sessionId = state.sessionId.value;
        if (sessionId == null) {
          showAppError('jonli_session_failed'.tr);
          return;
        }
        state.busy.value = true;
        try {
          final result = await Get.find<LiveRepository>().createTurn(
            sessionId: sessionId,
            filePath: recorded.path,
            speaker: speaker,
            clientTurnId: 't${DateTime.now().microsecondsSinceEpoch}_${_turnSeq++}',
          );
          final map = asMap(result.dataOrNull);
          if (map == null) {
            showAppError(result.errorOrNull ?? 'jonli_translate_failed'.tr);
            return;
          }
          state.lastOriginal.value =
              map['text_original']?.toString() ?? '';
          state.lastTranslated.value =
              map['text_translated']?.toString() ?? '';
          final audioUrl = map['audio_url']?.toString() ??
              map['tts_url']?.toString() ??
              '';
          if (audioUrl.isNotEmpty &&
              Get.isRegistered<VoicePlayerService>()) {
            await Get.find<VoicePlayerService>().toggle(
              id: 'jonli_$sessionId',
              path: audioUrl,
              duration: const Duration(seconds: 3),
            );
          }
        } finally {
          state.busy.value = false;
        }
      case SwapLanguages _:
        final my = state.myLanguage.value;
        state.myLanguage.value = state.otherLanguage.value;
        state.otherLanguage.value = my;
        // Restart session with new languages
        final old = state.sessionId.value;
        if (old != null) {
          await Get.find<LiveRepository>().endSession(old);
        }
        state.sessionId.value = null;
        await _ensureSession();
      case ToggleTheme _:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Get.find<ThemeController>()
            .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      case SelectMyLanguage a:
        state.myLanguage.value = a.language;
        final old = state.sessionId.value;
        if (old != null) {
          await Get.find<LiveRepository>().endSession(old);
        }
        state.sessionId.value = null;
        await _ensureSession();
      case SelectOtherLanguage a:
        state.otherLanguage.value = a.language;
        final old = state.sessionId.value;
        if (old != null) {
          await Get.find<LiveRepository>().endSession(old);
        }
        state.sessionId.value = null;
        await _ensureSession();
    }
  }
}
