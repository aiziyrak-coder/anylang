import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/theme/gradients.dart';
import 'chat_message.dart';
import 'chat_payload.dart';

class ChatState extends GetxController {
  /// Har ochilishda oshadi — eski API javoblari / UI chalkashmasin.
  final RxInt sessionId = 0.obs;

  final RxString peerName = ''.obs;
  final RxString peerInitial = ''.obs;
  final Rx<LinearGradient> peerAvatar = avatarTealGradient.obs;
  final RxnString peerAvatarUrl = RxnString();
  final RxBool peerOnline = false.obs;
  final RxString peerActivity = ''.obs;
  final RxBool peerTyping = false.obs;
  final RxnInt typingUserId = RxnInt();

  final RxInt chatId = 0.obs;
  final RxInt peerId = 0.obs;
  final RxBool isGroup = false.obs;
  String? myRole;
  bool isSuper = false;
  String? inviteLink;
  bool isMarketplace = false;
  String? marketplaceSlug;

  final RxBool selecting = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final Rxn<ChatMessage> pinnedBanner = Rxn<ChatMessage>();
  /// Barcha pinlangan xabarlar (Smart Pin paneli).
  final RxList<ChatMessage> pinnedMessages = <ChatMessage>[].obs;
  final RxBool pinned = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString input = ''.obs;
  final Rx<ChatMessage?> replyTo = Rx<ChatMessage?>(null);
  final RxBool recording = false.obs;
  final RxBool loading = true.obs;
  final RxBool loadError = false.obs;
  final RxBool sending = false.obs;
  final RxBool aiSuggesting = false.obs;
  /// Hozir yuklanayotgan AI uslubi (chip spinner).
  final RxnString aiSuggestTone = RxnString();
  final RxnString aiSuggestMessageId = RxnString();
  final RxBool searching = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool muted = false.obs;

  /// Telegram: chatlar bo'yicha scroll holati (qayta ochganda).
  final Map<int, double> _scrollOffsetByChat = {};
  final Map<int, bool> _scrollPinnedByChat = {};
  bool scrollPinnedToBottom = true;
  double? savedScrollOffset;

  void rememberScroll({required bool pinnedToBottom, double? offset}) {
    final id = chatId.value;
    if (id <= 0) return;
    _scrollPinnedByChat[id] = pinnedToBottom;
    if (pinnedToBottom) {
      _scrollOffsetByChat.remove(id);
    } else if (offset != null) {
      _scrollOffsetByChat[id] = offset;
    }
  }

  void bindPayload(ChatPayload p) {
    sessionId.value++;
    chatId.value = p.chatId;
    peerId.value = p.peerId;
    peerName.value = p.name;
    peerInitial.value = p.initial;
    peerAvatar.value = p.avatarGradient;
    peerAvatarUrl.value = p.avatarUrl;
    peerOnline.value = p.online;
    isGroup.value = p.isGroup;
    pinned.value = p.pinned;
    myRole = p.myRole;
    isSuper = p.isSuper;
    inviteLink = p.inviteLink;
    isMarketplace = p.isMarketplace;
    marketplaceSlug = p.marketplaceSlug;
    selecting.value = false;
    selectedIds.clear();
    pinnedBanner.value = null;
    pinnedMessages.clear();
    peerTyping.value = false;
    peerActivity.value = '';
    typingUserId.value = null;
    searching.value = false;
    searchQuery.value = '';
    input.value = '';
    replyTo.value = null;
    recording.value = false;
    sending.value = false;
    messages.clear();
    loading.value = true;
    loadError.value = false;
    scrollPinnedToBottom = _scrollPinnedByChat[p.chatId] ?? true;
    savedScrollOffset =
        scrollPinnedToBottom ? null : _scrollOffsetByChat[p.chatId];
  }
}
