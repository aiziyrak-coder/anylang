import 'dart:async';

import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../ui/items/friend_result_item.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import 'add_friend_action.dart';
import 'add_friend_content.dart';
import 'add_friend_payload.dart';
import 'add_friend_result.dart';
import 'add_friend_state.dart';

class AddFriendScreen extends Screen<AddFriendState, AddFriendPayload> {
  AddFriendScreen() : super(mobileContent: AddFriendContent());

  Timer? _debounce;
  bool _sendingRequest = false;

  @override
  void initState(AddFriendPayload? payload) {
    state.mode = payload?.mode ?? AddFriendMode.chat;
    state.query.value = '';
    state.searching.value = false;
    state.results.clear();
    state.sentRequests.clear();
    if (state.mode == AddFriendMode.friends) {
      _loadSentRequests();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
  }

  Future<void> _loadSentRequests() async {
    state.loadingSent.value = true;
    final result = await Get.find<FriendsRepository>().listRequests(
      type: 'outgoing',
      includeDeclined: true,
    );
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => AddFriendResult.fromRequestApi(Map<String, dynamic>.from(e)))
            .toList();
        state.sentRequests.assignAll(items);
      },
      failure: showAppError,
    );
    state.loadingSent.value = false;
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    // Backend: kamida 3 raqam (NUMBER_QUERY_TOO_SHORT)
    if (query.length < 3) {
      state.searching.value = false;
      state.results.clear();
      return;
    }
    state.searching.value = true;
    final result = await Get.find<ProfileRepository>().searchUsers(query);
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => AddFriendResult.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.results.assignAll(items);
      },
      failure: showAppError,
    );
    state.searching.value = false;
  }

  Future<void> _openChat(AddFriendResult user) async {
    if (SessionStore.isUserBlocked(user.id)) {
      showAppWarning('chat_blocked'.tr);
      return;
    }
    final chat = await Get.find<ChatRepository>().createChat(user.id);
    chat.when(
      success: (data) {
        final map = asMap(data);
        final chatId = (map?['id'] as num?)?.toInt() ?? 0;
        navigate(
          ChatScreen(),
          payload: ChatPayload(
            chatId: chatId,
            peerId: user.id,
            name: user.name,
            initial: user.initial,
            avatarGradient: user.avatarGradient,
            online: user.online,
          ),
        );
      },
      failure: showAppError,
    );
  }

  void _markRequested(AddFriendResult source) {
    final updated = source.copyWith(action: FriendActionState.requested);

    final resultsIdx = state.results.indexWhere((e) => e.id == source.id);
    if (resultsIdx >= 0) {
      state.results[resultsIdx] = updated;
      state.results.refresh();
    }

    final sentIdx = state.sentRequests.indexWhere((e) => e.id == source.id);
    if (sentIdx >= 0) {
      state.sentRequests[sentIdx] = updated;
      state.sentRequests.refresh();
    } else {
      state.sentRequests.insert(0, updated);
    }
  }

  void _markCancelled(AddFriendResult source) {
    final updated = AddFriendResult(
      id: source.id,
      initial: source.initial,
      avatarGradient: source.avatarGradient,
      name: source.name,
      subtitle: source.subtitle,
      online: source.online,
      action: FriendActionState.add,
    );

    final resultsIdx = state.results.indexWhere((e) => e.id == source.id);
    if (resultsIdx >= 0) {
      state.results[resultsIdx] = updated;
      state.results.refresh();
    }

    state.sentRequests.removeWhere((e) => e.id == source.id);
  }

  @override
  Future<void> actionHandler(AddFriendState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case AddFriendSearchChanged a:
        state.query.value = a.text;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () => _search(a.text));
      case OpenUserChat a:
        await _openChat(a.result);
      case MessageResult a:
        await _openChat(a.result);
      case SendFriendRequest a:
        if (_sendingRequest) return;
        _sendingRequest = true;
        final result = await Get.find<FriendsRepository>().sendRequest(a.result.id);
        result.when(
          success: (data) {
            final map = asMap(data);
            final requestId = (map?['id'] as num?)?.toInt();
            final status = map?['status']?.toString();
            if (status == 'accepted') {
              final updated = a.result.copyWith(action: FriendActionState.message);
              final resultsIdx =
                  state.results.indexWhere((e) => e.id == a.result.id);
              if (resultsIdx >= 0) {
                state.results[resultsIdx] = updated;
                state.results.refresh();
              }
              return;
            }
            _markRequested(
              requestId != null
                  ? a.result.copyWith(requestId: requestId)
                  : a.result,
            );
          },
          failure: showAppError,
        );
        _sendingRequest = false;
      case CancelFriendRequest a:
        if (_sendingRequest) return;
        final requestId = a.result.requestId;
        if (requestId == null) return;
        _sendingRequest = true;
        final result =
            await Get.find<FriendsRepository>().cancelRequest(requestId);
        result.when(
          success: (_) => _markCancelled(a.result),
          failure: showAppError,
        );
        _sendingRequest = false;
    }
  }
}
