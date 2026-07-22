import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../modal/language_bottom_sheet.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../ui/waveform_bars.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import '../select_language/select_language_option.dart';
import 'jonli_action.dart';
import 'jonli_state.dart';

// Jonli rejim — matnlar sessiya/STT dan keladi (bo'sh holat).
const String _demoOriginal = '';
const String _demoTranslated = '';

class JonliContent extends ScreenContent<JonliState> {

  // Asosiy ekran body'si ichida ochiladi — fon shaffof.
  JonliContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, JonliState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.dp),
            child: _languageRow(context, c, state, sendAction),
          ),
          Expanded(
            child: Obx(() => _body(c, state, state.mode.value, sendAction)),
          ),
          _bottom(c, state, sendAction),
        ],
      ),
    );
  }

  // ---- O'rtadagi body (almashadi) ----
  Widget _body(AppColors c, JonliState state, JonliMode mode, void Function(MyAction) sendAction) {
    if (mode == JonliMode.idle) {
      return _translationBody(c, state);
    }
    final isMe = mode == JonliMode.me;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.dp),
      child: Column(
        children: [
          Expanded(child: _recordingCenter(c, state, isMe)),
        ],
      ),
    );
  }

  Widget _languageRow(BuildContext context, AppColors c, JonliState state, void Function(MyAction) sendAction) {
    Widget card(String label, LanguageOption lang, VoidCallback onTap) => Expanded(
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14.dp),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 9.dp),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.dp),
                  border: Border.all(color: c.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: TextStyle(color: c.textSecondary, fontSize: 10.sp, letterSpacing: 0.4)),
                    SizedBox(height: 3.dp),
                    Row(
                      children: [
                        _flag(lang.flag),
                        SizedBox(width: 7.dp),
                        Flexible(child: Text(lang.nativeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Obx(() => Row(
          children: [
            card('jonli_my_lang'.tr, state.myLanguage.value, () => _openMyLanguage(context, state, sendAction)),
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
            card('jonli_interlocutor'.tr, state.otherLanguage.value, () => _openOtherLanguage(context, state, sendAction)),
          ],
        ));
  }

  Future<void> _openMyLanguage(BuildContext context, JonliState state, void Function(MyAction) sendAction) async {
    final picked = await showLanguageBottomSheet(
      context,
      title: 'jonli_my_lang'.tr,
      desc: 'jonli_my_lang_desc'.tr,
      selectedKey: state.myLanguage.value.key,
    );
    if (picked != null) sendAction(SelectMyLanguage(picked));
  }

  Future<void> _openOtherLanguage(BuildContext context, JonliState state, void Function(MyAction) sendAction) async {
    final picked = await showLanguageBottomSheet(
      context,
      title: 'jonli_interlocutor_title'.tr,
      desc: 'jonli_interlocutor_desc'.tr,
      selectedKey: state.otherLanguage.value.key,
    );
    if (picked != null) sendAction(SelectOtherLanguage(picked));
  }

  Widget _recordingCenter(AppColors c, JonliState state, bool isMe) {
    final color = isMe ? kLime : kSpeakBlue;
    final gradient = isMe ? limeButtonGradient : speakingBlueGradient;
    final flag = isMe ? state.myLanguage.value.flag : state.otherLanguage.value.flag;
    final lang = isMe ? state.myLanguage.value.nativeName : state.otherLanguage.value.nativeName;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _listeningPill(),
        SizedBox(height: 24.dp),
        _micCircle(c, gradient, color),
        SizedBox(height: 22.dp),
        _waveform(color),
        SizedBox(height: 16.dp),
        Text(
          (isMe ? 'jonli_you_speaking' : 'jonli_other_speaking').tr,
          style: TextStyle(color: c.textPrimary, fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6.dp),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _flag(flag),
            SizedBox(width: 6.dp),
            Text(lang, style: TextStyle(color: c.textSecondary, fontSize: 13.sp)),
          ],
        ),
      ],
    );
  }

  Widget _listeningPill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 7.dp),
      decoration: BoxDecoration(
        color: kListenRed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: kListenRed.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8.dp, height: 8.dp, decoration: const BoxDecoration(color: kListenRed, shape: BoxShape.circle)),
          SizedBox(width: 8.dp),
          Text('jonli_listening'.tr, style: TextStyle(color: kListenRed, fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _micCircle(AppColors c, LinearGradient gradient, Color color) {
    return SizedBox(
      width: 160.dp,
      height: 160.dp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 160.dp, height: 160.dp, decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle)),
          Container(width: 124.dp, height: 124.dp, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle)),
          Container(
            width: 104.dp,
            height: 104.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: SvgPicture.asset(
              'assets/icons/ic_mic.svg',
              width: 40.dp,
              height: 40.dp,
              colorFilter: ColorFilter.mode(c.onAccent, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waveform(Color color) {
    final recorder = Get.find<VoiceRecorderService>();
    return Obx(() {
      final samples = List<double>.of(recorder.liveSamples);
      return WaveformBars(
        color: color,
        maxHeight: 28,
        barCount: 18,
        barWidth: 4,
        gap: 5,
        samples: samples,
      );
    });
  }

  // ---- Variant C — tarjima / playback body ----
  Widget _translationBody(AppColors c, JonliState state) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.dp, 6.dp, 20.dp, 6.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 18.dp),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: 280.dp),
              padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16.dp),
                border: Border.all(color: c.outline),
              ),
              child: Text(
                _demoOriginal.isEmpty ? 'jonli_placeholder'.tr : _demoOriginal,
                style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
              ),
            ),
          ),
          SizedBox(height: 12.dp),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 11.dp),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16.dp),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Container(width: 7.dp, height: 7.dp, decoration: BoxDecoration(color: kSpeakBlue, shape: BoxShape.circle)),
                    SizedBox(width: 4.dp),
                  ],
                  SizedBox(width: 4.dp),
                  Text('jonli_translating'.tr, style: TextStyle(color: c.textSecondary, fontSize: 13.sp)),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.dp),
          _ttsCard(c, state),
        ],
      ),
    );
  }

  Widget _ttsCard(AppColors c, JonliState state) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.dp),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, color: c.accent, size: 18.dp),
              SizedBox(width: 8.dp),
              Text('jonli_reading_to_you'.tr, style: TextStyle(color: c.accent, fontSize: 12.sp, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              const Spacer(),
              _flag(state.myLanguage.value.flag),
              SizedBox(width: 6.dp),
              Text(state.myLanguage.value.nativeName, style: TextStyle(color: c.textSecondary, fontSize: 12.sp)),
            ],
          ),
          SizedBox(height: 12.dp),
          Text(
            _demoTranslated.isEmpty ? '“…”' : '“$_demoTranslated”',
            style: TextStyle(color: c.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14.dp),
          _waveform(c.accent),
        ],
      ),
    );
  }

  // ---- Pastki qism (doimiy) ----
  Widget _bottom(AppColors c, JonliState state, void Function(MyAction) sendAction) {
    return Column(
      children: [
        Obx(() => Text(
              (state.mode.value == JonliMode.idle ? 'jonli_hint_idle' : 'jonli_hint_recording').tr,
              style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
            )),
        SizedBox(height: 12.dp),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.dp),
          child: Row(
            children: [
              Expanded(child: _talkButton(c, state, sendAction, isMe: true)),
              SizedBox(width: 12.dp),
              Expanded(child: _talkButton(c, state, sendAction, isMe: false)),
            ],
          ),
        ),
        SizedBox(height: 8.dp),
      ],
    );
  }

  Widget _talkButton(AppColors c, JonliState state, void Function(MyAction) sendAction, {required bool isMe}) {
    return Obx(() {
      final active = state.mode.value == (isMe ? JonliMode.me : JonliMode.other);
      final gradient = active ? (isMe ? limeButtonGradient : speakingBlueGradient) : null;
      final flag = isMe ? state.myLanguage.value.flag : state.otherLanguage.value.flag;
      final lang = isMe ? state.myLanguage.value.nativeName : state.otherLanguage.value.nativeName;
      final labelColor = active ? c.onAccent : c.textSecondary;

      return GestureDetector(
        onTapDown: (_) => sendAction(StartSpeaking(isMe)),
        onTapUp: (_) => sendAction(StopSpeaking()),
        onTapCancel: () => sendAction(StopSpeaking()),
        child: Container(
          height: 104.dp,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? null : c.surface,
            gradient: gradient,
            borderRadius: BorderRadius.circular(20.dp),
            border: active ? null : Border.all(color: c.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_mic.svg',
                width: 26.dp,
                height: 26.dp,
                colorFilter: ColorFilter.mode(active ? c.onAccent : c.textFaint, BlendMode.srcIn),
              ),
              SizedBox(height: 6.dp),
              Text(
                (isMe ? 'jonli_you' : 'jonli_interlocutor').tr,
                style: TextStyle(color: labelColor, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3.dp),
              if (active)
                Text('jonli_holding'.tr, style: TextStyle(color: labelColor.withValues(alpha: 0.8), fontSize: 11.sp))
            ],
          ),
        ),
      );
    });
  }

  Widget _flag(String asset) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3.dp),
      child: Image.asset(asset, width: 20.dp, height: 14.dp, fit: BoxFit.cover),
    );
  }
}
