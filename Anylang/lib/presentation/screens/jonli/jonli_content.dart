import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../data/audio/voice_recorder_service.dart';
import '../../modal/language_bottom_sheet.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/items/jonli_transcript_item.dart';
import '../../ui/language_flag.dart';
import '../../ui/theme/colors.dart';
import '../../ui/waveform_bars.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import '../select_language/select_language_option.dart';
import 'jonli_action.dart';
import 'jonli_state.dart';

class JonliContent extends ScreenContent<JonliState> {
  JonliContent() : super(color: Colors.transparent);

  ScrollController? _transcriptScroll;
  Worker? _turnsWorker;

  @override
  void initContent() {
    _transcriptScroll = ScrollController();
  }

  @override
  void uiBuildFinished(JonliState state) {
    _turnsWorker?.dispose();
    _turnsWorker = ever(state.turns, (_) => _scrollToLatest());
  }

  @override
  void onClose() {
    _turnsWorker?.dispose();
    _turnsWorker = null;
    _transcriptScroll?.dispose();
    _transcriptScroll = null;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sc = _transcriptScroll;
      if (sc == null || !sc.hasClients) return;
      final max = sc.position.maxScrollExtent;
      final cur = sc.position.pixels;
      if (max - cur > 120) return;
      sc.animateTo(
        max,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(
    BuildContext context,
    JonliState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.dp),
            child: _languageRow(context, c, state, sendAction),
          ),
          SizedBox(height: 8.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.dp),
            child: Row(
              children: [
                Expanded(child: _voiceChip(c, state, sendAction)),
                SizedBox(width: 8.dp),
                _cameraChip(c, sendAction),
                SizedBox(width: 8.dp),
                _historyChip(c, sendAction),
              ],
            ),
          ),
          Obx(() {
            if (!state.liveLanguagesLoadFailed.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(14.dp, 8.dp, 14.dp, 0),
              child: _languagesBanner(c, sendAction),
            );
          }),
          Obx(() {
            if (!state.needsPremium.value) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.fromLTRB(14.dp, 8.dp, 14.dp, 0),
              child: _premiumCard(c, sendAction),
            );
          }),
          SizedBox(height: 10.dp),
          Expanded(child: _transcriptPane(c, state, sendAction)),
          Padding(
            padding: EdgeInsets.fromLTRB(14.dp, 4.dp, 14.dp, 8.dp),
            child: _sessionPanel(c, state, sendAction),
          ),
        ],
      ),
    );
  }

  Widget _languagesBanner(AppColors c, void Function(MyAction) sendAction) {
    return Material(
      color: c.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.dp),
        onTap: () => sendAction(ReloadLiveLanguages()),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 18.dp, color: c.danger),
              SizedBox(width: 10.dp),
              Expanded(
                child: Text(
                  'jonli_languages_failed'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'jonli_languages_retry'.tr,
                style: TextStyle(
                  color: c.danger,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumCard(AppColors c, void Function(MyAction) sendAction) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'jonli_premium_card_title'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.dp),
          Text(
            'jonli_premium_card_body'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              height: 1.35,
            ),
          ),
          SizedBox(height: 12.dp),
          PrimaryButton(
            text: 'jonli_premium_card_cta'.tr,
            onTap: () => sendAction(OpenJonliPlans()),
          ),
        ],
      ),
    );
  }

  Widget _voiceChip(
    AppColors c,
    JonliState state,
    void Function(MyAction) sendAction,
  ) {
    return Obx(() {
      final voiceKey = state.ttsVoice.value == 'male' ? 'male' : 'female';
      final speed = state.ttsSpeed.value;
      final speedLabel = speed == speed.roundToDouble()
          ? '${speed.toStringAsFixed(0)}x'
          : '${speed.toStringAsFixed(2)}x';
      final label = 'jonli_voice_chip'.trParams({
        'voice': voiceKey.tr,
        'speed': speedLabel,
      });

      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(99.dp),
          child: InkWell(
            borderRadius: BorderRadius.circular(99.dp),
            onTap: () => sendAction(OpenVoiceSettings()),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over_rounded,
                      size: 16.dp, color: c.accent),
                  SizedBox(width: 6.dp),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.dp),
                  Icon(Icons.tune_rounded, size: 15.dp, color: c.accent),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _cameraChip(AppColors c, void Function(MyAction) sendAction) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(99.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(99.dp),
        onTap: () => sendAction(OpenCameraTranslate()),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_outlined,
                  size: 16.dp, color: c.textPrimary),
              SizedBox(width: 6.dp),
              Text(
                'jonli_camera_chip'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyChip(AppColors c, void Function(MyAction) sendAction) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(99.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(99.dp),
        onTap: () => sendAction(OpenHistory()),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 16.dp, color: c.textPrimary),
              SizedBox(width: 6.dp),
              Text(
                'jonli_history_chip'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transcriptPane(
    AppColors c,
    JonliState state,
    void Function(MyAction) sendAction,
  ) {
    return Obx(() {
      final turns = state.turns;
      final empty = turns.isEmpty &&
          state.mode.value == JonliMode.idle &&
          !state.busy.value;

      if (empty) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.dp),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 42.dp, color: c.accent),
              SizedBox(height: 14.dp),
              Text(
                'jonli_empty_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                'jonli_hint_idle'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.dp),
              _historyFooter(c, sendAction),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _transcriptScroll,
        padding: EdgeInsets.fromLTRB(14.dp, 4.dp, 14.dp, 8.dp),
        itemCount: turns.length + 1,
        itemBuilder: (_, i) {
          if (i == turns.length) {
            return Padding(
              padding: EdgeInsets.only(top: 8.dp, bottom: 4.dp),
              child: _historyFooter(c, sendAction),
            );
          }
          final e = turns[i];
          return JonliTranscriptItem(
            entry: e,
            onRetry: e.failed && (e.audioPath ?? '').isNotEmpty
                ? () => sendAction(RetryTurn(e.clientTurnId))
                : null,
            onCopy: () {
              final text = [
                if (e.original.isNotEmpty) e.original,
                if (e.translated.isNotEmpty) e.translated,
              ].join('\n');
              if (text.isNotEmpty) sendAction(CopyTurnText(text));
            },
          );
        },
      );
    });
  }

  Widget _historyFooter(AppColors c, void Function(MyAction) sendAction) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.dp),
        onTap: () => sendAction(OpenHistory()),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.expand_more_rounded,
                  color: c.textSecondary, size: 20.dp),
              SizedBox(width: 8.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'jonli_history_today'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      'jonli_history_scroll_hint'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: c.textFaint, size: 20.dp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageRow(
    BuildContext context,
    AppColors c,
    JonliState state,
    void Function(MyAction) sendAction,
  ) {
    Widget card(String label, LanguageOption lang, VoidCallback onTap) =>
        Expanded(
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14.dp),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.dp, vertical: 9.dp),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.dp),
                  border: Border.all(color: c.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 10.sp,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 3.dp),
                    Row(
                      children: [
                        LanguageFlag(
                          url: lang.flagUrl,
                          emoji: lang.flagEmoji,
                          width: 20.dp,
                          height: 14.dp,
                        ),
                        SizedBox(width: 7.dp),
                        Flexible(
                          child: Text(
                            lang.nativeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Obx(
      () => Row(
        children: [
          card(
            'jonli_my_lang'.tr,
            state.myLanguage.value,
            () => _openMyLanguage(context, state, sendAction),
          ),
          SizedBox(width: 10.dp),
          Material(
            color: c.accentSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => sendAction(SwapLanguages()),
              child: Padding(
                padding: EdgeInsets.all(9.dp),
                child: SvgPicture.asset(
                  'assets/icons/ic_swap.svg',
                  width: 17.dp,
                  height: 17.dp,
                  colorFilter: ColorFilter.mode(c.accent, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.dp),
          card(
            'jonli_interlocutor'.tr,
            state.otherLanguage.value,
            () => _openOtherLanguage(context, state, sendAction),
          ),
        ],
      ),
    );
  }

  Future<void> _openMyLanguage(
    BuildContext context,
    JonliState state,
    void Function(MyAction) sendAction,
  ) async {
    final picked = await showLanguageBottomSheet(
      context,
      title: 'jonli_my_lang'.tr,
      desc: 'jonli_my_lang_desc'.tr,
      selectedKey: state.myLanguage.value.key,
      allowedLangCodes: state.liveLangCodes.toSet(),
    );
    if (picked != null) sendAction(SelectMyLanguage(picked));
  }

  Future<void> _openOtherLanguage(
    BuildContext context,
    JonliState state,
    void Function(MyAction) sendAction,
  ) async {
    final picked = await showLanguageBottomSheet(
      context,
      title: 'jonli_interlocutor_title'.tr,
      desc: 'jonli_interlocutor_desc'.tr,
      selectedKey: state.otherLanguage.value.key,
      allowedLangCodes: state.liveLangCodes.toSet(),
    );
    if (picked != null) sendAction(SelectOtherLanguage(picked));
  }

  /// Bitta waveform — level ValueNotifier orqali (RxList Obx emas).
  Widget _waveform(Color color, {int barCount = 22, double maxHeight = 22}) {
    final recorder = Get.find<VoiceRecorderService>();
    return ValueListenableBuilder<double>(
      valueListenable: recorder.level,
      builder: (_, _, _) {
        final samples = List<double>.of(recorder.liveSamples);
        return WaveformBars(
          color: color,
          maxHeight: maxHeight,
          barCount: barCount,
          barWidth: 3,
          gap: 3,
          samples: samples,
          scroll: recorder.liveScroll,
        );
      },
    );
  }

  /// Status + ikki hold-to-talk taraf (Siz | Suhbatdosh).
  Widget _sessionPanel(
    AppColors c,
    JonliState state,
    void Function(MyAction) sendAction,
  ) {
    return Obx(() {
      final busy = state.busy.value;
      final mode = state.mode.value;
      final recording = mode != JonliMode.idle;
      final meHot = mode == JonliMode.me;
      final otherHot = mode == JonliMode.other;
      final waveColor = otherHot ? kSpeakBlue : c.accent;

      final status = busy
          ? 'jonli_translating'.tr
          : (recording
              ? 'jonli_hint_recording'.tr
              : 'jonli_hint_idle'.tr);

      return Container(
        padding: EdgeInsets.fromLTRB(12.dp, 12.dp, 12.dp, 12.dp),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22.dp),
          border: Border.all(
            color: recording ? waveColor.withValues(alpha: 0.55) : c.outline,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (recording || busy)
                  Container(
                    width: 8.dp,
                    height: 8.dp,
                    margin: EdgeInsets.only(right: 8.dp),
                    decoration: BoxDecoration(
                      color: busy ? c.textFaint : waveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (busy)
                  SizedBox(
                    width: 14.dp,
                    height: 14.dp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.accent,
                    ),
                  ),
              ],
            ),
            if (recording) ...[
              SizedBox(height: 10.dp),
              _waveform(waveColor, barCount: 24, maxHeight: 24),
            ],
            SizedBox(height: 12.dp),
            Row(
              children: [
                Expanded(
                  child: _holdSpeakerButton(
                    c,
                    label: 'jonli_you'.tr,
                    hot: meHot,
                    enabled: !busy && (!recording || meHot),
                    accent: c.accent,
                    onDown: () {
                      HapticFeedback.mediumImpact();
                      sendAction(HoldSpeakStart(true));
                    },
                    onUp: () => sendAction(StopSpeaking()),
                  ),
                ),
                SizedBox(width: 10.dp),
                Expanded(
                  child: _holdSpeakerButton(
                    c,
                    label: 'jonli_interlocutor'.tr,
                    hot: otherHot,
                    enabled: !busy && (!recording || otherHot),
                    accent: kSpeakBlue,
                    onDown: () {
                      HapticFeedback.mediumImpact();
                      sendAction(HoldSpeakStart(false));
                    },
                    onUp: () => sendAction(StopSpeaking()),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _holdSpeakerButton(
    AppColors c, {
    required String label,
    required bool hot,
    required bool enabled,
    required Color accent,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!enabled || hot) return;
        onDown();
      },
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 18.dp),
        decoration: BoxDecoration(
          color: hot
              ? accent.withValues(alpha: 0.18)
              : (enabled ? c.background : c.background.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(16.dp),
          border: Border.all(
            color: hot
                ? accent
                : (enabled ? c.outline : c.outline.withValues(alpha: 0.5)),
            width: hot ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_rounded,
              size: 22.dp,
              color: hot
                  ? accent
                  : (enabled ? c.textSecondary : c.textFaint),
            ),
            SizedBox(height: 6.dp),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hot
                    ? accent
                    : (enabled ? c.textPrimary : c.textFaint),
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.dp),
            Text(
              hot ? 'jonli_holding'.tr : 'jonli_hold_hint'.tr,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hot ? accent.withValues(alpha: 0.9) : c.textFaint,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
