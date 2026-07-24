import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/permissions/app_permissions.dart';
import '../../utils/app_snackbar.dart';
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

  static const _exitWindow = Duration(seconds: 2);

  @override
  void initState(void payload) {
    // Yangilangan ilova: onboarding o'tib ketgan foydalanuvchilar uchun bir marta.
    if (!AppPermissions.alreadyRequested) {
      Future.microtask(() => AppPermissions.requestAllRequired());
    }
  }

  @override
  Future<void> actionHandler(MainState state, MyAction action) async {
    switch (action) {
      case TabSelected a:
        final prev = state.currentTab.value;
        state.currentTab.value = a.index;
        state.lastExitPromptAt = null;
        if (a.index == prev) return;
        // IndexedStack re-init qilmaydi — tab ochilganda soft refresh.
        if (a.index == 0) await _refreshConversations();
        if (a.index == 1) await _refreshFriends();
      case HandleSystemBack _:
        await _onSystemBack(state);
    }
  }

  Future<void> _onSystemBack(MainState state) async {
    // Boshqa tabda → avval Xabarlar.
    if (state.currentTab.value != 0) {
      state.currentTab.value = 0;
      state.lastExitPromptAt = null;
      await _refreshConversations();
      return;
    }

    // Xabarlarda: birinchi bosish — ogohlantirish, ikkinchi — chiqish.
    final now = DateTime.now();
    final last = state.lastExitPromptAt;
    if (last != null && now.difference(last) <= _exitWindow) {
      await SystemNavigator.pop();
      return;
    }
    state.lastExitPromptAt = now;
    showAppWarning('exit_press_again'.tr);
  }

  Future<void> _refreshConversations() async {
    if (!Get.isRegistered<MessagesState>()) return;
    final ms = Get.find<MessagesState>();
    if (ms.loading.value) return;
    final filter = ms.listFilter.value;
    final result = await Get.find<ChatRepository>().listChats(
      sort: filter == MessagesListFilter.unread ? 'unread' : 'activity',
      type: switch (filter) {
        MessagesListFilter.chats => 'direct',
        MessagesListFilter.groups => 'group',
        _ => null,
      },
    );
    final data = result.dataOrNull;
    if (data == null) return;
    var items = asList(data)
        .whereType<Map>()
        .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
        .where((c) => c.isGroup || !SessionStore.isUserBlocked(c.peerId))
        .toList();
    switch (filter) {
      case MessagesListFilter.groups:
        items = items.where((c) => c.isGroup).toList();
      case MessagesListFilter.chats:
        items = items.where((c) => !c.isGroup).toList();
      case MessagesListFilter.unread:
        items = items.where((c) => c.unread > 0).toList();
      case MessagesListFilter.all:
        break;
    }
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
