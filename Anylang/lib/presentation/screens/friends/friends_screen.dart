import 'package:flutter/material.dart';
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
import 'friend_request.dart';
import 'friends_action.dart';
import 'friends_content.dart';
import 'friends_requests_bottom_sheet.dart';
import 'friends_state.dart';

class FriendsScreen extends Screen<FriendsState, void> {
  FriendsScreen() : super(mobileContent: FriendsContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _loadPendingCount() async {
    final result = await Get.find<FriendsRepository>().listRequests(type: 'incoming');
    result.when(
      success: (data) {
        state.pendingCount.value = asList(data).whereType<Map>().length;
      },
      failure: showAppError,
    );
  }

  Future<void> _load() async {
    state.loading.value = true;
    final repo = Get.find<FriendsRepository>();
    final result = await repo.listFriends();
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
    await _loadPendingCount();
    state.loading.value = false;
  }

  Future<void> _openRequestsSheet() async {
    final result = await Get.find<FriendsRepository>().listRequests(type: 'incoming');
    var requests = <FriendRequest>[];
    result.when(
      success: (data) {
        requests = asList(data)
            .whereType<Map>()
            .map((e) => FriendRequest.fromApi(Map<String, dynamic>.from(e)))
            .where((r) => r.requestId > 0)
            .toList();
      },
      failure: (err) {
        showAppError(err);
        return;
      },
    );
    if (!context.mounted) return;
    await showFriendsRequestsBottomSheet(
      context,
      requests: requests,
      onAccept: (requestId) async {
        final r = await Get.find<FriendsRepository>().acceptRequest(requestId);
        r.when(
          success: (_) async {
            await _load();
          },
          failure: showAppError,
        );
      },
      onDecline: (requestId) async {
        final r = await Get.find<FriendsRepository>().declineRequest(requestId);
        r.when(
          success: (_) async {
            state.pendingCount.value =
                (state.pendingCount.value - 1).clamp(0, 999);
          },
          failure: showAppError,
        );
      },
    );
    await _loadPendingCount();
  }

  @override
  Future<void> actionHandler(FriendsState state, MyAction action) async {
    switch (action) {
      case FriendsSearchChanged a:
        state.query.value = a.text;
      case RefreshFriends _:
        await _load();
      case OpenFriendRequests _:
        await _openRequestsSheet();
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
              showAppError('chat_open_failed'.tr);
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
      case RemoveFriend a:
        final ok = await Get.dialog<bool>(
          AlertDialog(
            title: Text('friends_remove_title'.tr),
            content: Text(a.friend.name),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('settings_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(
                  'friends_remove'.tr,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final r = await Get.find<FriendsRepository>().removeFriend(a.friend.id);
        r.when(
          success: (_) {
            state.friends.removeWhere((f) => f.id == a.friend.id);
            showAppMessage('friends_removed'.tr);
          },
          failure: showAppError,
        );
    }
  }
}
