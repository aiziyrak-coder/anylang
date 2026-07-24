import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/realtime_sync_service.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../modal/conversation_actions_dialog.dart';
import '../../modal/chat_overflow_sheet.dart';
import '../../modal/new_chat_actions_dialog.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_friend/add_friend_payload.dart';
import '../add_friend/add_friend_result.dart';
import '../add_friend/add_friend_screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../create_group/create_group_screen.dart';
import '../group_settings/group_settings_payload.dart';
import '../group_settings/group_settings_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
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
    final filter = state.listFilter.value;
    final result = await Get.find<ChatRepository>().listChats(
      sort: filter == MessagesListFilter.unread ? 'unread' : 'activity',
      type: switch (filter) {
        MessagesListFilter.chats => 'direct',
        MessagesListFilter.groups => 'group',
        _ => null,
      },
    );
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.conversations.assignAll(_filterConversations(items, filter));
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  /// Guruhlar/Chatlar filterini clientda ham mustahkamlaydi (soft-reload
  /// yoki API xatosi DM ni guruhlar ichiga qo‘shib yubormasin).
  static List<Conversation> _filterConversations(
    List<Conversation> items,
    MessagesListFilter filter,
  ) {
    var out = items
        .where((c) => c.isGroup || !SessionStore.isUserBlocked(c.peerId))
        .toList();
    switch (filter) {
      case MessagesListFilter.groups:
        return out.where((c) => c.isGroup).toList();
      case MessagesListFilter.chats:
        return out.where((c) => !c.isGroup).toList();
      case MessagesListFilter.unread:
        return out.where((c) => c.unread > 0).toList();
      case MessagesListFilter.all:
        return out;
    }
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      state.searching.value = false;
      state.searchResults.clear();
      state.userResults.clear();
      return;
    }
    final seq = ++_searchSeq;
    state.searching.value = true;
    final chatFuture = Get.find<ChatRepository>().search(q);
    final userFuture = q.length >= 3
        ? Get.find<ProfileRepository>().searchUsers(q)
        : null;
    final chatResult = await chatFuture;
    if (userFuture != null) {
      final userResult = await userFuture;
      if (seq != _searchSeq) return;
      userResult.when(
        success: (data) {
          final items = asList(data)
              .whereType<Map>()
              .map((e) => AddFriendResult.fromApi(Map<String, dynamic>.from(e)))
              .where((u) => !SessionStore.isUserBlocked(u.id))
              .toList();
          state.userResults.assignAll(items);
        },
        failure: (err) {
          state.userResults.clear();
          showAppError(err);
        },
      );
    } else {
      state.userResults.clear();
    }
    if (seq != _searchSeq) return;
    chatResult.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Conversation.fromApi(Map<String, dynamic>.from(e)))
            .where((c) => c.isGroup || !SessionStore.isUserBlocked(c.peerId))
            .toList();
        state.searchResults.assignAll(items);
      },
      failure: showAppError,
    );
    if (seq == _searchSeq) {
      state.searching.value = false;
    }
  }

  Future<void> _openUserChat(AddFriendResult user) async {
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
            avatarUrl: user.avatarUrl,
          ),
        );
      },
      failure: showAppError,
    );
  }

  Future<void> _showNewSheet(Rect anchor) async {
    final choice = await showNewChatActionsDialog(context, anchor: anchor);
    if (choice == NewChatMenuAction.chat) {
      await navigate(
        AddFriendScreen(),
        payload: const AddFriendPayload(mode: AddFriendMode.chat),
      );
      await _load();
    } else if (choice == NewChatMenuAction.group) {
      await navigate(CreateGroupScreen());
      await _load();
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
          state.userResults.clear();
        } else {
          _searchDebounce = Timer(
            const Duration(milliseconds: 350),
            () => _search(a.text),
          );
        }
      case OpenConversation a:
        final conv = a.conversation;
        if (!conv.isGroup && SessionStore.isUserBlocked(conv.peerId)) {
          showAppWarning('chat_blocked'.tr);
          return;
        }
        final idx = state.conversations.indexWhere((c) => c.id == conv.id);
        if (idx >= 0 && state.conversations[idx].unread > 0) {
          state.conversations[idx] = state.conversations[idx].copyWith(
            unread: 0,
            highlighted: false,
          );
        }
        await navigate(
          ChatScreen(),
          payload: ChatPayload(
            chatId: conv.id,
            peerId: conv.peerId,
            name: conv.name,
            initial: conv.initial,
            avatarGradient: conv.avatarGradient,
            online: conv.online,
            avatarUrl: conv.avatarUrl,
            isGroup: conv.isGroup,
            pinned: conv.pinned,
            myRole: conv.myRole,
            isSuper: conv.isSuper,
            inviteLink: conv.inviteLink,
          ),
        );
        if (Get.isRegistered<RealtimeSyncService>()) {
          Get.find<RealtimeSyncService>().setActiveChat(null);
        }
        await _load();
      case NewConversation a:
        await _showNewSheet(a.anchor);
      case NewGroupRequested _:
        await navigate(CreateGroupScreen());
        await _load();
      case RefreshConversations _:
        await _load();
      case OpenUserChat a:
        await _openUserChat(a.user);
      case ChangeMessagesFilter a:
        if (state.listFilter.value == a.filter) return;
        state.listFilter.value = a.filter;
        await _load();
      case LongPressConversation a:
        await _onConversationLongPress(a.conversation, a.anchor);
      case EnterListSelect a:
        state.selecting.value = true;
        state.selectedIds
          ..clear()
          ..add(a.seed.id);
      case ToggleListSelect a:
        if (state.selectedIds.contains(a.conversation.id)) {
          state.selectedIds.remove(a.conversation.id);
        } else {
          state.selectedIds.add(a.conversation.id);
        }
        state.selectedIds.refresh();
        if (state.selectedIds.isEmpty) state.selecting.value = false;
      case ExitListSelect _:
        state.selecting.value = false;
        state.selectedIds.clear();
      case BulkMuteSelected _:
        final repo = Get.find<ChatRepository>();
        for (final id in state.selectedIds.toList()) {
          await repo.muteChat(id);
        }
        state.selecting.value = false;
        state.selectedIds.clear();
        await _load();
      case BulkHideSelected _:
        final repo = Get.find<ChatRepository>();
        for (final id in state.selectedIds.toList()) {
          await repo.hideChat(id);
        }
        state.selecting.value = false;
        state.selectedIds.clear();
        await _load();
      case BulkDeleteSelected _:
        final repo = Get.find<ChatRepository>();
        for (final id in state.selectedIds.toList()) {
          await repo.clearHistory(id);
          await repo.hideChat(id);
        }
        state.selecting.value = false;
        state.selectedIds.clear();
        await _load();
    }
  }

  Future<void> _onConversationLongPress(Conversation conv, Rect anchor) async {
    final muted = conv.muted || SessionStore.isChatMuted(conv.id);
    final chosen = await showConversationActionsDialog(
      context,
      conversation: conv,
      anchor: anchor,
      muted: muted,
    );
    if (chosen == null) return;
    final repo = Get.find<ChatRepository>();
    switch (chosen) {
      case ChatOverflowAction.mute:
        final next = !muted;
        await SessionStore.setChatMuted(conv.id, next);
        final result =
            next ? await repo.muteChat(conv.id) : await repo.unmuteChat(conv.id);
        if (result.errorOrNull != null) {
          await SessionStore.setChatMuted(conv.id, muted);
          showAppError(result.errorOrNull);
          return;
        }
        final idx = state.conversations.indexWhere((c) => c.id == conv.id);
        if (idx >= 0) {
          state.conversations[idx] =
              state.conversations[idx].copyWith(muted: next);
        }
      case ChatOverflowAction.pin:
        final next = !conv.pinned;
        final result =
            next ? await repo.pinChat(conv.id) : await repo.unpinChat(conv.id);
        if (result.errorOrNull != null) {
          showAppError(result.errorOrNull);
          return;
        }
        final idx = state.conversations.indexWhere((c) => c.id == conv.id);
        if (idx >= 0) {
          state.conversations[idx] =
              state.conversations[idx].copyWith(pinned: next);
        }
        // Pin order — ro‘yxatni qayta yuklash.
        await _load();
      case ChatOverflowAction.profile:
        if (conv.isGroup || conv.peerId <= 0) return;
        final result =
            await Get.find<ProfileRepository>().getPublicUser(conv.peerId);
        result.when(
          success: (data) {
            final map = asMap(data);
            if (map == null) return;
            navigate(
              UserProfileScreen(),
              payload: UserProfilePayload.fromApi(map),
            );
          },
          failure: showAppError,
        );
      case ChatOverflowAction.groupSettings:
        if (!conv.isGroup) return;
        await navigate(
          GroupSettingsScreen(),
          payload: GroupSettingsPayload(
            chatId: conv.id,
            title: conv.name,
            avatarUrl: conv.avatarUrl,
            myRole: conv.myRole,
            isSuper: conv.isSuper,
            inviteLink: conv.inviteLink,
            memberLimit: conv.memberLimit,
          ),
        );
        await _load();
      case ChatOverflowAction.clearHistory:
        final canEveryone =
            !conv.isGroup || conv.myRole == 'owner' || conv.myRole == 'admin';
        final body = !conv.isGroup
            ? 'chat_clear_body_dm'.tr
            : (canEveryone
                ? 'chat_clear_body_group_admin'.tr
                : 'chat_clear_body_group'.tr);
        final clearChoice = await showTelegramActionSheet(
          context,
          title: 'chat_clear_title'.tr,
          body: body,
          actions: [
            if (canEveryone)
              TelegramSheetAction(
                id: 'everyone',
                label: 'chat_clear_for_everyone'.tr,
                danger: true,
              ),
            TelegramSheetAction(
              id: 'me',
              label: 'chat_clear_for_me'.tr,
              danger: true,
            ),
          ],
        );
        if (clearChoice == null) return;
        final result = await repo.clearHistory(
          conv.id,
          forEveryone: clearChoice == 'everyone',
        );
        result.when(
          success: (_) => showAppMessage('chat_history_cleared'.tr),
          failure: showAppError,
        );
      case ChatOverflowAction.deleteChat:
        final delChoice = await showTelegramActionSheet(
          context,
          title: 'chat_delete_chat_title'.tr,
          body: 'chat_delete_confirm'.tr,
          actions: [
            TelegramSheetAction(
              id: 'delete',
              label: 'chat_overflow_delete_chat'.tr,
              danger: true,
            ),
          ],
        );
        if (delChoice != 'delete') return;
        final result = await repo.hideChat(conv.id);
        result.when(
          success: (_) {
            state.conversations.removeWhere((c) => c.id == conv.id);
          },
          failure: showAppError,
        );
      case ChatOverflowAction.block:
        if (conv.isGroup || conv.peerId <= 0) return;
        final blockChoice = await showTelegramActionSheet(
          context,
          title: 'chat_block_title'.tr,
          body: 'chat_block_confirm'.tr,
          actions: [
            TelegramSheetAction(
              id: 'block',
              label: 'chat_overflow_block'.tr,
              danger: true,
            ),
          ],
        );
        if (blockChoice != 'block') return;
        await SessionStore.setUserBlocked(conv.peerId, true);
        await Get.find<ProfileRepository>().blockUser(conv.peerId);
        await repo.hideChat(conv.id);
        state.conversations.removeWhere((c) => c.id == conv.id);
      case ChatOverflowAction.search:
        break;
    }
  }
}
