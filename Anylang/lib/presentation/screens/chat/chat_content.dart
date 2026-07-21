import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/chat_message_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'chat_action.dart';
import 'chat_app_bar.dart';
import 'chat_composer.dart';
import 'chat_state.dart';

class ChatContent extends ScreenContent<ChatState> {
  // UI resurslari — content darajasida (mobile↔tablet almashsa qayta yaratiladi).
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Worker? _messagesWorker;

  @override
  void onClose() {
    _messagesWorker?.dispose();
    _input.dispose();
    _scroll.dispose();
  }

  @override
  void uiBuildFinished(ChatState state) {
    // Yangi xabar qo'shilganda ro'yxatni pastga surish.
    _messagesWorker = ever(state.messages, (_) => _scrollToBottom());
    _scrollToBottom(animate: false);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context, ChatState state,
      void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              ChatAppBar(
                name: state.peerName,
                initial: state.peerInitial,
                avatarGradient: state.peerAvatar,
                online: state.peerOnline,
                onBack: () => sendAction(Back()),
                onMenu: () {},
              ),
              Expanded(child: _list(c, state, sendAction)),
              Obx(
                () => ChatComposer(
                  controller: _input,
                  recording: state.recording.value,
                  showSend: state.input.value.trim().isNotEmpty,
                  reply: state.replyTo.value,
                  onChanged: (v) => sendAction(InputChanged(v)),
                  onSend: () {
                    sendAction(SendText());
                    _input.clear();
                  },
                  onMic: () => sendAction(StartRecording()),
                  onAttach: () => sendAction(OpenAttachMenu()),
                  onCancelReply: () => sendAction(CancelReply()),
                  onCancelRecording: () => sendAction(CancelRecording()),
                  onSendVoice: () => sendAction(SendVoice()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(AppColors c, ChatState state,
      void Function(MyAction action) sendAction) {
    return Obx(
      () => ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
        itemCount: state.messages.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _dateChip(c);
          final msg = state.messages[i - 1];
          return ChatMessageItem(
            message: msg,
            onLongPress: () => sendAction(LongPressMessage(msg)),
          );
        },
      ),
    );
  }

  Widget _dateChip(AppColors c) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: 8.dp),
        padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 4.dp),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12.dp),
        ),
        child: Text(
          'chat_today'.tr,
          style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
        ),
      ),
    );
  }
}
