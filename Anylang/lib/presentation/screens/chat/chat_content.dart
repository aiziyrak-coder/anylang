import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
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
  final Map<String, GlobalKey> _messageKeys = {};
  Worker? _messagesWorker;
  Worker? _inputWorker;

  @override
  void onClose() {
    _messagesWorker?.dispose();
    _inputWorker?.dispose();
    _input.dispose();
    _scroll.dispose();
    if (Get.isRegistered<VoiceRecorderService>()) {
      Get.find<VoiceRecorderService>().cancel();
    }
  }

  @override
  void uiBuildFinished(ChatState state) {
    // Yangi xabar qo'shilganda ro'yxatni pastga surish.
    _messagesWorker = ever(state.messages, (_) => _scrollToBottom());
    // Yuborish xatosida matnni qaytarish — controller bilan sync.
    _inputWorker = ever(state.input, (v) {
      if (_input.text != v) {
        _input.value = TextEditingValue(
          text: v,
          selection: TextSelection.collapsed(offset: v.length),
        );
      }
    });
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

  void _scrollToMessage(String messageId) {
    final ctx = _messageKeys[messageId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.35,
    );
  }

  GlobalKey _keyFor(String id) =>
      _messageKeys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context, ChatState state,
      void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final recorder = Get.find<VoiceRecorderService>();

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
                () {
                  final samples = List<double>.of(recorder.liveSamples);
                  return ChatComposer(
                    controller: _input,
                    recording: state.recording.value,
                    showSend: state.input.value.trim().isNotEmpty &&
                        !state.sending.value,
                    reply: state.replyTo.value,
                    peerName: state.peerName,
                    recordElapsed: recorder.elapsedLabel.value,
                    recordSamples: samples,
                    onChanged: (v) => sendAction(InputChanged(v)),
                    onSend: () => sendAction(SendText()),
                    onMic: () => sendAction(StartRecording()),
                    onAttach: () => sendAction(OpenAttachMenu()),
                    onCancelReply: () => sendAction(CancelReply()),
                    onCancelRecording: () => sendAction(CancelRecording()),
                    onSendVoice: () => sendAction(SendVoice()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(AppColors c, ChatState state,
      void Function(MyAction action) sendAction) {
    return Obx(() {
      if (state.loading.value) return const AppLoading();
      if (state.messages.isEmpty) {
        return AppEmptyState(
          icon: Icons.forum_outlined,
          title: 'chat_empty'.tr,
          subtitle: 'chat_empty_hint'.tr,
        );
      }
      return ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
        itemCount: state.messages.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _dateChip(c);
          final msg = state.messages[i - 1];
          final key = _keyFor(msg.id);
          return KeyedSubtree(
            key: key,
            child: ChatMessageItem(
              message: msg,
              onLongPress: () {
                final box = key.currentContext?.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                final anchor = box.localToGlobal(Offset.zero) & box.size;
                sendAction(LongPressMessage(msg, anchor));
              },
              onReplyTap: _scrollToMessage,
            ),
          );
        },
      );
    });
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
