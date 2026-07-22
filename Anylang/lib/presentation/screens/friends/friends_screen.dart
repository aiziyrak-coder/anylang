import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_friend/add_friend_payload.dart';
import '../add_friend/add_friend_screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import 'friend.dart';
import 'friends_action.dart';
import 'friends_content.dart';
import 'friends_state.dart';

class FriendsScreen extends Screen<FriendsState, void> {
  FriendsScreen() : super(mobileContent: FriendsContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    final result = await Get.find<FriendsRepository>().listFriends();
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
            .where((f) => !SessionStore.isUserBlocked(f.id))
            .toList();
        state.friends.assignAll(items);
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  @override
  Future<void> actionHandler(FriendsState state, MyAction action) async {
    switch (action) {
      case FriendsSearchChanged a:
        state.query.value = a.text;
      case RefreshFriends _:
        await _load();
      case OpenChat a:
        if (SessionStore.isUserBlocked(a.friend.id)) {
          showAppWarning('chat_blocked'.tr);
          return;
        }
        final result = await Get.find<ChatRepository>().createChat(a.friend.id);
        result.when(
          success: (data) {
            final map = asMap(data);
            final chatId = (map?['id'] as num?)?.toInt() ?? 0;
            if (chatId <= 0) {
              showAppError('Suhbat ochilmadi');
              return;
            }
            navigate(
              ChatScreen(),
              payload: ChatPayload(
                chatId: chatId,
                peerId: a.friend.id,
                name: a.friend.name,
                initial: a.friend.initial,
                avatarGradient: a.friend.avatarGradient,
                online: a.friend.online,
                avatarUrl: a.friend.avatarUrl,
              ),
            );
          },
          failure: showAppError,
        );
      case AddFriend _:
        await navigate(
          AddFriendScreen(),
          payload: const AddFriendPayload(mode: AddFriendMode.friends),
        );
        await _load();
    }
  }
}
