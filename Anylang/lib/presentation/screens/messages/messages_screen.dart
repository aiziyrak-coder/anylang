import 'dart:async';

import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_friend/add_friend_payload.dart';
import '../add_friend/add_friend_screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import 'conversation.dart';
import 'messages_action.dart';
import 'messages_content.dart';
import 'messages_state.dart';

class MessagesScreen extends Screen<MessagesState, void> {
  MessagesScreen() : super(mobileContent: MessagesContent());

  Timer? _searchDebounce;
  int _searchSeq = 0;

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    await connectRealtimeIfNeeded();
    state.loading.value = true;
    state.conversations.clear();
    final result = await Get.find<ChatRepository>().listChats();
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
            .where((c) => !SessionStore.isUserBlocked(c.peerId))
            .toList();
        state.conversations.assignAll(items);
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      state.searching.value = false;
      state.searchResults.clear();
      return;
    }
    final seq = ++_searchSeq;
    state.searching.value = true;
    final result = await Get.find<ChatRepository>().search(q);
    if (seq != _searchSeq) return;
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
            .where((c) => !SessionStore.isUserBlocked(c.peerId))
            .toList();
        state.searchResults.assignAll(items);
      },
      failure: showAppError,
    );
    if (seq == _searchSeq) {
      state.searching.value = false;
    }
  }

  @override
  Future<void> actionHandler(MessagesState state, MyAction action) async {
    switch (action) {
      case SearchChanged a:
        state.query.value = a.text;
        _searchDebounce?.cancel();
        if (a.text.trim().isEmpty) {
          state.searching.value = false;
          state.searchResults.clear();
        } else {
          _searchDebounce = Timer(
            const Duration(milliseconds: 350),
            () => _search(a.text),
          );
        }
      case OpenConversation a:
        final conv = a.conversation;
        if (SessionStore.isUserBlocked(conv.peerId)) {
          showAppWarning('chat_blocked'.tr);
          return;
        }
        navigate(
          ChatScreen(),
          payload: ChatPayload(
            chatId: conv.id,
            peerId: conv.peerId,
            name: conv.name,
            initial: conv.initial,
            avatarGradient: conv.avatarGradient,
            online: conv.online,
            avatarUrl: conv.avatarUrl,
          ),
        );
      case NewConversation _:
        navigate(
          AddFriendScreen(),
          payload: const AddFriendPayload(mode: AddFriendMode.chat),
        );
      case RefreshConversations _:
        await _load();
    }
  }
}
