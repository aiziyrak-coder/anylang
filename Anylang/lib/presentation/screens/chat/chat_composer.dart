import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/frosted_bar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../ui/waveform_bars.dart';
import '../../utils/size_controller.dart';
import 'chat_message.dart';

/// Suhbat pastki paneli: reply ko'rinishi + input/record almashinuvi.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool recording;
  final bool showSend;
  final ChatMessage? reply;
  final String peerName;
  final String recordElapsed;
  final List<double> recordSamples;

  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final VoidCallback onAttach;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendVoice;
  final VoidCallback? onMicTapHint;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.recording,
    required this.showSend,
    required this.reply,
    required this.onChanged,
    required this.onSend,
    required this.onMic,
    required this.onAttach,
    required this.onCancelReply,
    required this.onCancelRecording,
    required this.onSendVoice,
    this.peerName = '',
    this.recordElapsed = '0:00',
    this.recordSamples = const [],
    this.onMicTapHint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return FrostedBar(
      border: Border(top: BorderSide(color: c.outline.withValues(alpha: 0.45))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 12.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reply != null && !recording) _replyPreview(c),
              recording ? _recordRow(c) : _inputRow(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyPreview(AppColors c) {
    final target = reply!;
    final author = target.isOutgoing ? 'chat_you'.tr : peerName;
    return Container(
      margin: EdgeInsets.only(bottom: 8.dp),
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12.dp),
      ),
      child: Row(
        children: [
          Container(
            width: 3.dp,
            height: 36.dp,
            decoration: BoxDecoration(
              color: c.accentText,
              borderRadius: BorderRadius.circular(2.dp),
            ),
          ),
          SizedBox(width: 10.dp),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.isEmpty ? 'chat_reply_to'.tr : author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.dp),
                Text(
                  target.previewText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                ),
              ],
            ),
          ),
          MyIconButton(
            onClick: onCancelReply,
            icon: Icons.close_rounded,
            iconColor: c.textSecondary,
            iconSize: 18.dp,
            backgroundColor: Colors.transparent,
            borderRadius: 12.dp,
            padding: EdgeInsets.all(4.dp),
          ),
        ],
      ),
    );
  }

  Widget _inputRow(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MyIconButton(
          onClick: onAttach,
          icon: Icons.add_rounded,
          iconColor: c.accentText,
          iconSize: 22.dp,
          backgroundColor: c.surface,
          border: Border.all(color: c.surfaceBorder, width: 0.7),
          borderRadius: 22.dp,
          padding: EdgeInsets.all(10.dp),
        ),
        SizedBox(width: 8.dp),
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: 44.dp),
            padding: EdgeInsets.symmetric(horizontal: 16.dp),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
              border: Border.all(color: c.surfaceBorder, width: 0.7),
              borderRadius: BorderRadius.circular(22.dp),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 4,
              cursorColor: c.accent,
              style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11.dp),
                hintText: 'chat_input_hint'.tr,
                hintStyle: TextStyle(color: c.textFaint, fontSize: 15.sp),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.dp),
        showSend ? _sendButton(c) : _micButton(c),
      ],
    );
  }

  Widget _sendButton(AppColors c) {
    return MyIconButton(
      onClick: onSend,
      icon: Icons.send_rounded,
      iconColor: c.onAccent,
      iconSize: 22.dp,
      backgroundGradient: limeButtonGradient,
      borderRadius: 22.dp,
      padding: EdgeInsets.all(11.dp),
    );
  }

  Widget _micButton(AppColors c) {
    return Semantics(
      label: 'chat_mic_hold'.tr,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.dp),
          onLongPress: onMic,
          onTap: onMicTapHint,
          child: Ink(
            decoration: BoxDecoration(
              gradient: limeButtonGradient,
              borderRadius: BorderRadius.circular(22.dp),
            ),
            padding: EdgeInsets.all(11.dp),
            child: Icon(Icons.mic_rounded, color: c.onAccent, size: 22.dp),
          ),
        ),
      ),
    );
  }

  Widget _recordRow(AppColors c) {
    return Row(
      children: [
        MyIconButton(
          onClick: onCancelRecording,
          icon: Icons.delete_outline_rounded,
          iconColor: kListenRed,
          iconSize: 22.dp,
          backgroundColor: c.surface,
          border: Border.all(color: c.surfaceBorder, width: 0.7),
          borderRadius: 22.dp,
          padding: EdgeInsets.all(10.dp),
        ),
        SizedBox(width: 8.dp),
        Expanded(
          child: Container(
            height: 44.dp,
            padding: EdgeInsets.symmetric(horizontal: 14.dp),
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
              border: Border.all(color: c.surfaceBorder, width: 0.7),
              borderRadius: BorderRadius.circular(22.dp),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: WaveformBars(
                        color: c.accent,
                        maxHeight: 22,
                        barCount: 30,
                        samples: recordSamples,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.dp),
                Text(
                  recordElapsed,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.dp),
        MyIconButton(
          onClick: onSendVoice,
          icon: Icons.send_rounded,
          iconColor: c.onAccent,
          iconSize: 22.dp,
          backgroundGradient: limeButtonGradient,
          borderRadius: 22.dp,
          padding: EdgeInsets.all(11.dp),
        ),
      ],
    );
  }
}
