import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../ui/waveform_bars.dart';
import '../../utils/size_controller.dart';
import 'chat_message.dart';

/// Suhbat pastki paneli: reply ko'rinishi + input/record almashinuvi.
/// Holatga (`recording`, `showSend`, `reply`) qarab ikki ko'rinishdan birini
/// chizadi. Barcha o'zaro ta'sir callback'lar orqali `ChatContent`'ga boradi.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool recording;
  final bool showSend; // input bo'sh emas → yuborish, aks holda mikrofon
  final ChatMessage? reply;

  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final VoidCallback onAttach;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendVoice;

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
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.outline)),
      ),
      padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 12.dp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null && !recording) _replyPreview(c),
          recording ? _recordRow(c) : _inputRow(c),
        ],
      ),
    );
  }

  // Reply ko'rinishi (input ustida)
  Widget _replyPreview(AppColors c) {
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
            height: 34.dp,
            decoration: BoxDecoration(
              color: c.accent,
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
                  'chat_reply_to'.tr,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.dp),
                Text(
                  reply!.previewText(),
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

  // Oddiy input qatori: "+", matn maydoni, mic/yuborish
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
          border: Border.all(color: c.surfaceBorder),
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
              color: c.surface,
              border: Border.all(color: c.surfaceBorder),
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
        MyIconButton(
          onClick: showSend ? onSend : onMic,
          icon: showSend ? Icons.send_rounded : Icons.mic_rounded,
          iconColor: c.onAccent,
          iconSize: 22.dp,
          backgroundGradient: limeButtonGradient,
          borderRadius: 22.dp,
          padding: EdgeInsets.all(11.dp),
        ),
      ],
    );
  }

  // Ovoz yozish qatori: savat, to'lqin + timer, yuborish
  Widget _recordRow(AppColors c) {
    return Row(
      children: [
        MyIconButton(
          onClick: onCancelRecording,
          icon: Icons.delete_outline_rounded,
          iconColor: kListenRed,
          iconSize: 22.dp,
          backgroundColor: c.surface,
          border: Border.all(color: c.surfaceBorder),
          borderRadius: 22.dp,
          padding: EdgeInsets.all(10.dp),
        ),
        SizedBox(width: 8.dp),
        Expanded(
          child: Container(
            height: 44.dp,
            padding: EdgeInsets.symmetric(horizontal: 14.dp),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.surfaceBorder),
              borderRadius: BorderRadius.circular(22.dp),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: WaveformBars(
                      color: c.accent,
                      maxHeight: 22,
                      barCount: 30,
                    ),
                  ),
                ),
                SizedBox(width: 10.dp),
                Text(
                  'chat_record_time'.tr,
                  style: TextStyle(color: c.textPrimary, fontSize: 14.sp),
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
