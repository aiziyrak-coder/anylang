import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../friends/friend.dart';
import '../friends/friends_state.dart';
import '../messages/conversation.dart';
import '../messages/messages_state.dart';
import 'main_action.dart';
import 'main_content.dart';
import 'main_state.dart';

class MainScreen extends Screen<MainState, void> {
  MainScreen() : super(mobileContent: MainContent());

  @override
  Future<void> actionHandler(MainState state, MyAction action) async {
    switch (action) {
      case TabSelected a:
        final prev = state.currentTab.value;
        state.currentTab.value = a.index;
        if (a.index == prev) return;
        // IndexedStack re-init qilmaydi — tab ochilganda soft refresh.
        if (a.index == 0) await _refreshConversations();
        if (a.index == 1) await _refreshFriends();
    }
  }

  Future<void> _refreshConversations() async {
    if (!Get.isRegistered<MessagesState>()) return;
    final ms = Get.find<MessagesState>();
    if (ms.loading.value) return;
    final result = await Get.find<ChatRepository>().listChats();
    final data = result.dataOrNull;
    if (data == null) return;
    final items = asList(data)
        .whereType<Map>()
        .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
        .where((c) => !SessionStore.isUserBlocked(c.peerId))
        .toList();
    ms.conversations.assignAll(items);
  }

  Future<void> _refreshFriends() async {
    if (!Get.isRegistered<FriendsState>()) return;
    final fs = Get.find<FriendsState>();
    if (fs.loading.value) return;
    final result = await Get.find<FriendsRepository>().listFriends();
    final data = result.dataOrNull;
    if (data == null) return;
    final items = asList(data)
        .whereType<Map>()
        .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
        .where((f) => !SessionStore.isUserBlocked(f.id))
        .toList();
    fs.friends.assignAll(items);
    await _loadPendingCount(fs);
  }

  Future<void> _loadPendingCount(FriendsState fs) async {
    final result = await Get.find<FriendsRepository>().listRequests(type: 'incoming');
    result.when(
      success: (data) {
        final count = asList(data)
            .whereType<Map>()
            .where((e) => (e['status'] as String?) == 'pending')
            .length;
        fs.pendingCount.value = count;
      },
      failure: (_) {},
    );
  }
}
