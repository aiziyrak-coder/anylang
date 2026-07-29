import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/core/mappers.dart';
import '../../../data/network/forward_pending_store.dart';
import '../../modal/ai_reply_styles_bottom_sheet.dart';
import '../../modal/smart_pins_bottom_sheet.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/chat_smart_pins_bar.dart';
import '../../ui/connection_status_banner.dart';
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
  Worker? _searchMatchWorker;
  Worker? _searchMatchIdsWorker;
  Worker? _loadingWorker;
  ChatState? _boundState;
  int _lastMessageCount = 0;
  /// Telegram: pastda bo'lsa yangi xabar / keyboard bilan pastga yopishadi.
  bool _pinnedToBottom = true;
  double _lastKeyboardInset = 0;
  static const double _bottomStickThreshold = 72;

  @override
  void initContent() {
    _scroll.addListener(_onScroll);
  }

  @override
  void onClose() {
    _scroll.removeListener(_onScroll);
    // Keyingi ochilishda (shu chat) scroll holatini tiklash.
    if (_scroll.hasClients && _boundState != null) {
      _boundState!.rememberScroll(
        pinnedToBottom: _isNearBottom(),
        offset: _scroll.offset,
      );
    }
    _boundState = null;
    _messagesWorker?.dispose();
    _inputWorker?.dispose();
    _searchWorker?.dispose();
    _searchMatchWorker?.dispose();
    _searchMatchIdsWorker?.dispose();
    _loadingWorker?.dispose();
    _input.dispose();
    _search.dispose();
    _scroll.dispose();
    if (Get.isRegistered<VoiceRecorderService>()) {
      Get.find<VoiceRecorderService>().cancel();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _pinnedToBottom = _isNearBottom();
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return _pinnedToBottom;
    final pos = _scroll.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return _pinnedToBottom;
    return pos.maxScrollExtent - pos.pixels <= _bottomStickThreshold;
  }

  /// Telegram: keyboard ochilganda pastda bo'lsa oxirgi xabarlar ko'rinsin;
  /// yuqoriga scroll qilingan bo'lsa — o'qish joyi saqlansin (offset + delta).
  void _onKeyboardInsetChanged(double inset) {
    final delta = inset - _lastKeyboardInset;
    if (delta.abs() < 0.5) {
      _lastKeyboardInset = inset;
      return;
    }
    final stick = _pinnedToBottom || _isNearBottom();
    _lastKeyboardInset = inset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!pos.hasContentDimensions) return;
      if (stick) {
        _pinnedToBottom = true;
        final target = pos.maxScrollExtent;
        if ((pos.pixels - target).abs() > 0.5) {
          _scroll.jumpTo(target);
        }
      } else {
        final next = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
        if ((pos.pixels - next).abs() > 0.5) {
          _scroll.jumpTo(next);
        }
      }
    });
  }

  @override
  void uiBuildFinished(ChatState state) {
    _boundState = state;
    _lastMessageCount = state.messages.length;
    _lastKeyboardInset = 0;
    // Faqat yangi xabar qo'shilganda pastga — status yangilanishida sakramasin.
    _messagesWorker = ever(state.messages, (list) {
      final n = list.length;
      if (n > _lastMessageCount) {
        final newest = n > 0 ? list.last : null;
        final mine = newest?.isOutgoing == true;
        // O'z xabari yoki pastga yopishgan bo'lsa — pastga.
        if (mine || _pinnedToBottom || _isNearBottom()) {
          final bulkOrFirst = n - _lastMessageCount > 1;
          if (bulkOrFirst || mine) {
            _jumpToBottomSettled();
          } else {
            _scrollToBottom(animate: true);
          }
        }
      }
      _lastMessageCount = n;
    });
    // Yuklash tugagach — saqlangan scroll yoki past.
    _loadingWorker = ever(state.loading, (loading) {
      if (!loading && state.messages.isNotEmpty) {
        _restoreOrJumpBottom(state);
      }
      if (loading) {
        _lastMessageCount = 0;
      }
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
    _searchMatchWorker = ever(state.searchMatchIndex, (_) {
      _scrollToCurrentSearchMatch(state);
    });
    _searchMatchIdsWorker = ever(state.searchMatchIds, (_) {
      _scrollToCurrentSearchMatch(state);
    });
    if (!state.loading.value && state.messages.isNotEmpty) {
      _restoreOrJumpBottom(state);
    }
  }

  void _scrollToCurrentSearchMatch(ChatState state) {
    final ids = state.searchMatchIds;
    if (ids.isEmpty) return;
    final i = state.searchMatchIndex.value.clamp(0, ids.length - 1);
    final id = ids[i];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMessage(id);
    });
  }

  void _restoreOrJumpBottom(ChatState state) {
    if (state.scrollPinnedToBottom || state.savedScrollOffset == null) {
      _jumpToBottomSettled();
      return;
    }
    final saved = state.savedScrollOffset!;
    _pinnedToBottom = false;
    void jump() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(saved.clamp(0.0, max));
      _pinnedToBottom = _isNearBottom();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  /// Layout barqaror bo‘lguncha bir necha frame jump — ochilishda scroll animatsiyasi yo‘q.
  void _jumpToBottomSettled() {
    _pinnedToBottom = true;
    void jump() {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - target).abs() > 1) {
        _scroll.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jump();
        WidgetsBinding.instance.addPostFrameCallback((_) => jump());
      });
    });
  }

  void _scrollToBottom({bool animate = true}) {
    _pinnedToBottom = true;
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

  Future<void> _openSmartPins(BuildContext context, ChatState state) async {
    final pins = state.pinnedMessages.isNotEmpty
        ? state.pinnedMessages.toList()
        : [
            if (state.pinnedBanner.value != null) state.pinnedBanner.value!,
          ];
    if (pins.isEmpty || !context.mounted) return;
    final id = await showSmartPinsBottomSheet(context, pins: pins);
    if (id != null) _scrollToMessage(id);
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

  ChatMessage? _prevMessage(List<Object> items, int index) {
    for (var i = index - 1; i >= 0; i--) {
      final item = items[i];
      if (item is ChatMessage) return item;
    }
    return null;
  }

  ChatMessage? _nextMessage(List<Object> items, int index) {
    for (var i = index + 1; i < items.length; i++) {
      final item = items[i];
      if (item is ChatMessage) return item;
    }
    return null;
  }

  bool _sameIncomingSender(ChatMessage a, ChatMessage b) {
    if (a.isOutgoing || b.isOutgoing) return false;
    if (a.senderId != null && b.senderId != null) {
      return a.senderId == b.senderId;
    }
    final an = a.senderName?.trim();
    final bn = b.senderName?.trim();
    if (an != null && bn != null && an.isNotEmpty && bn.isNotEmpty) {
      return an == bn;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, ChatState state,
      FutureOr<void> Function(MyAction action) sendAction) {
    final c = context.appColors;
    final recorder = Get.find<VoiceRecorderService>();
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // Keyboard ochilishi/yopilishi — Telegram scroll qoidasi.
    if ((keyboardInset - _lastKeyboardInset).abs() > 0.5) {
      _onKeyboardInsetChanged(keyboardInset);
    }
    // App bar / composer taxminiy balandligi — list padding.
    final topPad = topInset + 66.dp;

    return ChatWallpaperBackground(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Obx(() {
                final selecting = state.selecting.value;
                final bottomPad =
                    bottomInset + (selecting ? 12.dp : 72.dp);
                return Padding(
                  padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
                  child: Column(
                    children: [
                      const ConnectionStatusBanner(),
                      Obx(() {
                        final pins = state.pinnedMessages.toList();
                        if (pins.isEmpty) {
                          final pin = state.pinnedBanner.value;
                          if (pin == null) return const SizedBox.shrink();
                          return ChatSmartPinsBar(
                            pins: [pin],
                            onTapPin: _scrollToMessage,
                            onOpenAll: () => _openSmartPins(context, state),
                          );
                        }
                        return ChatSmartPinsBar(
                          pins: pins,
                          onTapPin: _scrollToMessage,
                          onOpenAll: () => _openSmartPins(context, state),
                        );
                      }),
                      Expanded(child: _list(c, state, sendAction)),
                    ],
                  ),
                );
              }),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Obx(
                () => ChatAppBar(
                  name: state.peerName.value,
                  initial: state.peerInitial.value,
                  avatarGradient: state.peerAvatar.value,
                  avatarUrl: state.peerAvatarUrl.value,
                  online: state.peerOnline.value,
                  statusText: _peerStatusText(state),
                  searching: state.searching.value,
                  hasSearchQuery: state.searchQuery.value.trim().isNotEmpty,
                  searchMatchCount: state.searchMatchIds.length,
                  searchMatchIndex: state.searchMatchIndex.value,
                  searchController: _search,
                  selecting: state.selecting.value,
                  selectedCount: state.selectedIds.length,
                  onBack: () => sendAction(Back()),
                  onMenu: (rect) => sendAction(OpenChatMenu(rect)),
                  onPeerTap: () => sendAction(OpenPeerProfile()),
                  onOpenSearch: () => sendAction(ToggleChatSearch()),
                  onCloseSearch: () => sendAction(ToggleChatSearch()),
                  onSearchChanged: (v) => sendAction(ChatSearchChanged(v)),
                  onSearchPrev: () => sendAction(ChatSearchPrev()),
                  onSearchNext: () => sendAction(ChatSearchNext()),
                  onForwardSelected: () => sendAction(ForwardSelectedMessages()),
                  onDeleteSelected: () => sendAction(DeleteSelectedMessages()),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Obx(
                () {
                  if (state.selecting.value) {
                    return const SizedBox.shrink();
                  }
                  final samples = List<double>.of(recorder.liveSamples);
                  final fwd = Get.isRegistered<ForwardPendingStore>()
                      ? Get.find<ForwardPendingStore>()
                      : null;
                  final hasFwd = fwd?.hasPending == true;
                  final fwdItems = fwd?.items.toList() ?? const [];
                  final showSender = fwd?.showSender.value ?? true;
                  return ChatComposer(
                    controller: _input,
                    recording: state.recording.value,
                    showSend: !state.sending.value &&
                        (state.input.value.trim().isNotEmpty || hasFwd),
                    reply: state.replyTo.value,
                    peerName: state.peerName.value,
                    recordElapsed: recorder.elapsedLabel.value,
                    recordSamples: samples,
                    forwardCount: fwdItems.length,
                    forwardPreview: fwdItems.isEmpty
                        ? null
                        : fwdItems.first.preview,
                    forwardSenderLabel: fwdItems.isEmpty
                        ? null
                        : fwdItems.first.senderLabel,
                    forwardShowSender: showSender,
                    onToggleForwardSender: () =>
                        sendAction(ToggleForwardShowSender()),
                    onCancelForward: () => sendAction(CancelForwardDraft()),
                    onChanged: (v) => sendAction(InputChanged(v)),
                    onSend: () => sendAction(SendText()),
                    onMic: () => sendAction(StartRecording()),
                    onAttach: () => sendAction(OpenAttachMenu()),
                    onAiSuggest: () async {
                      final tone = await showAiReplyStylesBottomSheet(context);
                      if (tone != null) {
                        sendAction(SuggestAiReply(tone: tone));
                      }
                    },
                    aiLoading: state.aiSuggesting.value,
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
      FutureOr<void> Function(MyAction action) sendAction) {
    return Obx(() {
      if (state.loading.value) return const AppLoading();
      if (state.loadError.value && state.messages.isEmpty) {
        return AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'chat_load_failed'.tr,
          subtitle: 'common_retry'.tr,
        );
      }
      final selecting = state.selecting.value;
      final selectedIds = state.selectedIds.toSet();
      final q = state.searchQuery.value.trim().toLowerCase();
      final matchIds = state.searchMatchIds.toSet();
      final currentMatchId = state.searchMatchIds.isEmpty
          ? null
          : state.searchMatchIds[
              state.searchMatchIndex.value.clamp(0, state.searchMatchIds.length - 1)];
      final messages = state.messages.toList();
      if (messages.isEmpty) {
        return AppEmptyState(
          icon: Icons.forum_outlined,
          title: 'chat_empty'.tr,
          subtitle: 'chat_empty_hint'.tr,
        );
      }
      final items = _buildListItems(messages);
      return ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          selecting ? 0 : 14.dp,
          12.dp,
          selecting ? 0 : 14.dp,
          12.dp,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          if (item is String) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: selecting ? 14.dp : 0),
              child: _dateChip(c, item),
            );
          }
          final msg = item as ChatMessage;
          final key = _keyFor(msg.id);
          final isGroup = state.isGroup.value;
          var showSenderName = false;
          var showAvatar = false;
          if (isGroup && !msg.isOutgoing) {
            final prev = _prevMessage(items, i);
            final next = _nextMessage(items, i);
            showSenderName =
                prev == null || !_sameIncomingSender(prev, msg);
            showAvatar = next == null || !_sameIncomingSender(msg, next);
          }
          // Auto business card chat oqimida ko‘rsatilmaydi.
          const showAutoCard = false;
          final isCurrentHit = currentMatchId != null && msg.id == currentMatchId;
          return KeyedSubtree(
            key: key,
            child: ChatMessageItem(
              message: msg,
              isGroup: isGroup,
              showSenderName: showSenderName,
              showAvatar: showAvatar,
              showAutoBusinessCard: showAutoCard,
              selecting: selecting,
              selected: selectedIds.contains(msg.id),
              searchHighlight: isCurrentHit,
              onTap: selecting
                  ? () => sendAction(ToggleSelectMessage(msg))
                  : (q.isNotEmpty && matchIds.contains(msg.id)
                      ? () {
                          final idx = state.searchMatchIds.indexOf(msg.id);
                          if (idx >= 0) state.searchMatchIndex.value = idx;
                          _scrollToMessage(msg.id);
                        }
                      : null),
              onSenderTap: (!selecting &&
                      !msg.isOutgoing &&
                      (msg.senderId ?? 0) > 0)
                  ? () => sendAction(OpenSenderProfile(msg.senderId!))
                  : null,
              onLongPress: () {
                final box = key.currentContext?.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                final anchor = box.localToGlobal(Offset.zero) & box.size;
                sendAction(
                  LongPressMessage(
                    msg,
                    anchor,
                    isGroup: isGroup,
                    showSenderName: showSenderName,
                    showAvatar: showAvatar,
                  ),
                );
              },
              onReplyTap: _scrollToMessage,
              onProductTap: msg.type == ChatMsgType.product
                  ? () => sendAction(OpenChatProduct(msg))
                  : null,
              onJoinGroupInvite: selecting
                  ? null
                  : (token) => sendAction(JoinGroupInvite(token)),
              onContactMessage: selecting
                  ? null
                  : (msg.type == ChatMsgType.contact
                      ? () => sendAction(OpenSharedContactChat(msg))
                      : null),
              onContactAdd: selecting
                  ? null
                  : (msg.type == ChatMsgType.contact
                      ? () => sendAction(AddSharedContact(msg))
                      : null),
              onAcceptOffer: (!selecting &&
                      msg.type == ChatMsgType.offer &&
                      !msg.isOutgoing)
                  ? () => sendAction(AcceptOffer(msg))
                  : null,
              onCounterOffer: (!selecting &&
                      msg.type == ChatMsgType.offer &&
                      !msg.isOutgoing)
                  ? () => sendAction(CounterOffer(msg))
                  : null,
              onReplyToRfq: (!selecting &&
                      msg.type == ChatMsgType.rfq &&
                      !msg.isOutgoing)
                  ? () => sendAction(ReplyToRfq(msg))
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
