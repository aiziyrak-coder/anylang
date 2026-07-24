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

  final RxBool selecting = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final Rxn<ChatMessage> pinnedBanner = Rxn<ChatMessage>();
  final RxBool pinned = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString input = ''.obs;
  final Rx<ChatMessage?> replyTo = Rx<ChatMessage?>(null);
  final RxBool recording = false.obs;
  final RxBool loading = true.obs;
  final RxBool sending = false.obs;
  final RxBool searching = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool muted = false.obs;

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
    selecting.value = false;
    selectedIds.clear();
    pinnedBanner.value = null;
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
  }
}
