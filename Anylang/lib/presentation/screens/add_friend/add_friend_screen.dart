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

  void _upsertResult(AddFriendResult updated) {
    final next = state.results.map((e) {
      return e.id == updated.id ? updated : e;
    }).toList();
    // Yangi list — Obx kafolatlangan rebuild.
    state.results.assignAll(next);

    final sent = state.sentRequests.toList();
    final sentIdx = sent.indexWhere((e) => e.id == updated.id);
    if (updated.action == FriendActionState.requested ||
        updated.action == FriendActionState.message) {
      if (sentIdx >= 0) {
        sent[sentIdx] = updated;
      } else {
        sent.insert(0, updated);
      }
    } else {
      sent.removeWhere((e) => e.id == updated.id);
    }
    state.sentRequests.assignAll(sent);
  }

  void _markRequested(AddFriendResult source, {int? requestId}) {
    _upsertResult(
      source.copyWith(
        action: FriendActionState.requested,
        requestId: requestId ?? source.requestId,
      ),
    );
  }

  void _markCancelled(AddFriendResult source) {
    _upsertResult(
      AddFriendResult(
        id: source.id,
        initial: source.initial,
        avatarGradient: source.avatarGradient,
        name: source.name,
        subtitle: source.subtitle,
        online: source.online,
        action: FriendActionState.add,
      ),
    );
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
        if (a.result.action == FriendActionState.requested) return;
        _sendingRequest = true;
        // Optimistic: tugma darhol "So'rov yuborildi".
        _markRequested(a.result);
        final result =
            await Get.find<FriendsRepository>().sendRequest(a.result.id);
        result.when(
          success: (data) {
            final map = asMap(data);
            final requestId = (map?['id'] as num?)?.toInt();
            final status = map?['status']?.toString();
            if (status == 'accepted' || map?['auto_accepted'] == true) {
              _upsertResult(
                a.result.copyWith(action: FriendActionState.message),
              );
              return;
            }
            _markRequested(a.result, requestId: requestId);
          },
          failure: (err) {
            final msg = err?.toString() ?? '';
            // Allaqachon yuborilgan — UI requested holatida qolsin.
            if (msg.contains('REQUEST_ALREADY_SENT') ||
                msg.contains('allaqachon')) {
              _markRequested(a.result);
              return;
            }
            // Boshqa xato — tugmani qaytarish.
            _markCancelled(a.result);
            showAppError(err);
          },
        );
        _sendingRequest = false;
      case CancelFriendRequest a:
        if (_sendingRequest) return;
        final requestId = a.result.requestId;
        if (requestId == null) {
          // requestId yo'q bo'lsa ham UI ni qaytarib, so'rovlarni yangilaymiz.
          _markCancelled(a.result);
          await _loadSentRequests();
          return;
        }
        _sendingRequest = true;
        final result =
            await Get.find<FriendsRepository>().cancelRequest(requestId);
        result.when(
          success: (_) => _markCancelled(a.result),
          failure: (err) {
            showAppError(err);
          },
        );
        _sendingRequest = false;
    }
  }
}
