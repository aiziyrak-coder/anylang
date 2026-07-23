import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/core/mappers.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/chat_wallpaper_background.dart';
import '../../ui/items/chat_message_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'chat_action.dart';
import 'chat_app_bar.dart';
import 'chat_composer.dart';
import 'chat_message.dart';
import 'chat_state.dart';

class ChatContent extends ScreenContent<ChatState> {
  // UI resurslari — content darajasida (mobile↔tablet almashsa qayta yaratiladi).
  final TextEditingController _input = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  Worker? _messagesWorker;
  Worker? _inputWorker;
  Worker? _searchWorker;
  int _lastMessageCount = 0;

  @override
  void onClose() {
    _messagesWorker?.dispose();
    _inputWorker?.dispose();
    _searchWorker?.dispose();
    _input.dispose();
    _search.dispose();
    _scroll.dispose();
    if (Get.isRegistered<VoiceRecorderService>()) {
      Get.find<VoiceRecorderService>().cancel();
    }
  }

  @override
  void uiBuildFinished(ChatState state) {
    _lastMessageCount = state.messages.length;
    // Faqat yangi xabar qo'shilganda pastga — status yangilanishida sakramasin.
    _messagesWorker = ever(state.messages, (list) {
      final n = list.length;
      if (n > _lastMessageCount) {
        _scrollToBottom();
      }
      _lastMessageCount = n;
    });
    // Yuborish xatosida matnni qaytarish — controller bilan sync.
    _inputWorker = ever(state.input, (v) {
      if (_input.text != v) {
        _input.value = TextEditingValue(
          text: v,
          selection: TextSelection.collapsed(offset: v.length),
        );
      }
    });
    _searchWorker = ever(state.searchQuery, (v) {
      if (_search.text != v) {
        _search.value = TextEditingValue(
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

  List<Object> _buildListItems(List<ChatMessage> messages) {
    final out = <Object>[];
    String? lastDayKey;
    for (final msg in messages) {
      final dayKey = chatDayKey(msg.createdAt);
      if (dayKey.isNotEmpty && dayKey != lastDayKey) {
        out.add(formatChatDayLabel(msg.createdAt));
        lastDayKey = dayKey;
      }
      out.add(msg);
    }
    return out;
  }

  @override
  Widget build(BuildContext context, ChatState state,
      void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final recorder = Get.find<VoiceRecorderService>();
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // App bar / composer taxminiy balandligi — list padding.
    final topPad = topInset + 66.dp;
    final bottomPad = bottomInset + 72.dp;

    return ChatWallpaperBackground(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
                child: _list(c, state, sendAction),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Obx(
                () => ChatAppBar(
                  name: state.peerName,
                  initial: state.peerInitial,
                  avatarGradient: state.peerAvatar,
                  online: state.peerOnline.value,
                  statusText: _peerStatusText(state),
                  searching: state.searching.value,
                  hasSearchQuery: state.searchQuery.value.trim().isNotEmpty,
                  searchController: _search,
                  onBack: () => sendAction(Back()),
                  onMenu: () => sendAction(OpenChatMenu()),
                  onPeerTap: () => sendAction(OpenPeerProfile()),
                  onCloseSearch: () => sendAction(ToggleChatSearch()),
                  onSearchChanged: (v) => sendAction(ChatSearchChanged(v)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Obx(
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
                    onMicTapHint: () => showAppMessage('chat_mic_hold_hint'.tr),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _peerStatusText(ChatState state) {
    if (!state.peerTyping.value && state.peerActivity.value.isEmpty) {
      return null;
    }
    return switch (state.peerActivity.value) {
      'photo' => 'chat_activity_photo'.tr,
      'file' => 'chat_activity_file'.tr,
      'voice' => 'chat_activity_voice'.tr,
      'video' => 'chat_activity_video'.tr,
      _ => 'chat_typing'.tr,
    };
  }

  Widget _list(AppColors c, ChatState state,
      void Function(MyAction action) sendAction) {
    return Obx(() {
      if (state.loading.value) return const AppLoading();
      final q = state.searchQuery.value.trim().toLowerCase();
      final messages = q.isEmpty
          ? state.messages.toList()
          : state.messages
              .where((m) => m.previewText().toLowerCase().contains(q))
              .toList();
      if (state.messages.isEmpty) {
        return AppEmptyState(
          icon: Icons.forum_outlined,
          title: 'chat_empty'.tr,
          subtitle: 'chat_empty_hint'.tr,
        );
      }
      if (q.isNotEmpty && messages.isEmpty) {
        return AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'chat_search_empty'.tr,
          subtitle: 'chat_search_empty_hint'.tr,
        );
      }
      final items = _buildListItems(messages);
      return ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          if (item is String) {
            return _dateChip(c, item);
          }
          final msg = item as ChatMessage;
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
              onProductTap: msg.type == ChatMsgType.product
                  ? () => sendAction(OpenChatProduct(msg))
                  : null,
            ),
          );
        },
      );
    });
  }

  Widget _dateChip(AppColors c, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.dp),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 5.dp),
          decoration: BoxDecoration(
            color: c.isDark
                ? const Color(0xCC152A42)
                : const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(
              color: c.isDark
                  ? const Color(0x22FFFFFF)
                  : const Color(0x66FFFFFF),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: c.isDark
                    ? const Color(0x44000000)
                    : const Color(0x140B1F36),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
