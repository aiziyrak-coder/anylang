import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/audio/voice_player_service.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/audio/waveform_utils.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/forward_pending_store.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/realtime_sync_service.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../../data/network/socket_service.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../modal/attachment_bottom_sheet.dart';
import '../../modal/location_picker_bottom_sheet.dart';
import '../../modal/chat_overflow_dialog.dart';
import '../../modal/chat_overflow_sheet.dart';
import '../../modal/image_picker.dart';
import '../../modal/message_actions_dialog.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../group_settings/group_settings_payload.dart';
import '../group_settings/group_settings_screen.dart';
import '../main/main_state.dart';
import '../messages/messages_state.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'chat_action.dart';
import 'chat_content.dart';
import 'chat_message.dart';
import 'chat_payload.dart';
import 'chat_state.dart';

class ChatScreen extends Screen<ChatState, ChatPayload> {
  ChatScreen() : super(mobileContent: ChatContent());

  int _seq = 0;
  Timer? _typingDebounce;
  bool _lastTypingSent = false;
  int? _boundChatId;

  @override
  void initState(ChatPayload? payload) {
    final p = payload;
    if (p == null) {
      popBackNavigate();
      return;
    }
    state.bindPayload(p);
    _boundChatId = p.chatId;
    state.muted.value = SessionStore.isChatMuted(p.chatId);
    if (Get.isRegistered<RealtimeSyncService>()) {
      Get.find<RealtimeSyncService>().setActiveChat(p.chatId);
    }
    // Real-time: WS ulangani va tinglovchi qayta bog'langani shart.
    unawaited(connectRealtimeIfNeeded());
    final session = state.sessionId.value;
    _loadMessages(p.chatId, session);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    final bound = _boundChatId;
    if (bound != null && Get.isRegistered<RealtimeSyncService>()) {
      final sync = Get.find<RealtimeSyncService>();
      // Keyingi chat ochilganda dispose keyinroq kelishi mumkin —
      // faqat hali shu chat active bo'lsa tozalaymiz.
      if (sync.activeChatId == bound) {
        sync.setActiveChat(null);
      }
    }
    super.dispose();
  }

  Future<void> _loadMessages(int chatId, int session) async {
    final result = await Get.find<ChatRepository>().listMessages(chatId);
    // Chat / session almashgan bo'lsa — eski javobni yozmang.
    if (state.sessionId.value != session || state.chatId.value != chatId) {
      return;
    }
    result.when(
      success: (data) {
        if (state.sessionId.value != session || state.chatId.value != chatId) {
          return;
        }
        final me = SessionStore.userId();
        final raw = asList(data)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final items = raw.map((e) => _fromApi(e, me)).toList();
        final filled = _fillMissingReplies(items, raw, me);
        // Faqat shu chatga tegishli live xabarlarni saqlab qolamiz.
        final liveOnly = state.messages
            .where((m) => filled.every((f) => f.id != m.id))
            .toList();
        final merged = [...filled, ...liveOnly]
          ..sort((a, b) {
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return at.compareTo(bt);
          });
        state.messages.assignAll(merged);
        final pinned = merged.where((m) => m.pinned).toList();
        state.pinnedBanner.value = pinned.isNotEmpty ? pinned.last : null;
        final ids = filled
            .where((m) => !m.isOutgoing)
            .map((m) => int.tryParse(m.id))
            .whereType<int>()
            .toList();
        if (ids.isNotEmpty) {
          Get.find<ChatRepository>().markRead(chatId, ids);
        }
        if (chatId > 0) {
          unawaited(_loadPinned(chatId, session));
        }
      },
      failure: (err) {
        if (state.sessionId.value == session && state.chatId.value == chatId) {
          showAppError(err);
        }
      },
    );
    if (state.sessionId.value == session && state.chatId.value == chatId) {
      state.loading.value = false;
    }
  }

  Future<void> _loadPinned(int chatId, int session) async {
    final result = await Get.find<ChatRepository>().listPinnedMessages(chatId);
    if (state.sessionId.value != session || state.chatId.value != chatId) {
      return;
    }
    result.when(
      success: (data) {
        if (state.sessionId.value != session || state.chatId.value != chatId) {
          return;
        }
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (items.isEmpty) return;
        final me = SessionStore.userId();
        final mapped = mapChatMessageFromApi(
          items.first,
          me: me,
          peerName: state.peerName.value,
        );
        state.pinnedBanner.value = mapped.withPinned(true);
      },
      failure: (_) {},
    );
  }

  /// Eski API faqat `reply_to_id` bersa — lokal xabarlaridan sitata yig'iladi.
  List<ChatMessage> _fillMissingReplies(
    List<ChatMessage> items,
    List<Map<String, dynamic>> raw,
    int? me,
  ) {
    final byId = {for (final m in items) m.id: m};
    final out = <ChatMessage>[];
    for (var i = 0; i < items.length; i++) {
      final msg = items[i];
      if (msg.reply != null) {
        out.add(msg);
        continue;
      }
      final replyToId = raw[i]['reply_to_id'];
      if (replyToId == null) {
        out.add(msg);
        continue;
      }
      final parent = byId['$replyToId'];
      if (parent == null) {
        out.add(msg);
        continue;
      }
      final reply = ChatReply(
        author: parent.isOutgoing ? 'chat_you'.tr : state.peerName.value,
        preview: parent.previewText(),
        messageId: parent.id,
      );
      out.add(_withReply(msg, reply));
    }
    return out;
  }

  ChatMessage _withReply(ChatMessage msg, ChatReply reply) {
    if (msg.type == ChatMsgType.voice) {
      return ChatMessage.voice(
        id: msg.id,
        dir: msg.dir,
        time: msg.time,
        createdAt: msg.createdAt,
        duration: msg.voiceDuration ?? '0:00',
        durationMs: msg.voiceDurationMs,
        path: msg.voicePath,
        samples: msg.voiceSamples,
        downloaded: msg.voiceDownloaded,
        status: msg.status,
        reply: reply,
        senderId: msg.senderId,
        senderName: msg.senderName,
        senderAvatarUrl: msg.senderAvatarUrl,
      );
    }
    return ChatMessage.text(
      id: msg.id,
      dir: msg.dir,
      time: msg.time,
      createdAt: msg.createdAt,
      text: msg.text ?? '',
      textOriginal: msg.textOriginal,
      showingOriginal: msg.showingOriginal,
      status: msg.status,
      reply: reply,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderAvatarUrl: msg.senderAvatarUrl,
    );
  }

  ChatMessage _fromApi(
    Map<String, dynamic> json,
    int? me, {
    ChatReply? fallbackReply,
  }) {
    return mapChatMessageFromApi(
      json,
      me: me,
      peerName: state.peerName.value,
      fallbackReply: fallbackReply,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Future<void> actionHandler(ChatState state, MyAction action) async {
    switch (action) {
      case InputChanged a:
        state.input.value = a.text;
        _handleTyping(state, a.text);

      case SendText _:
        await _sendComposer(state);

      case OpenAttachMenu _:
        final kind = await showAttachmentBottomSheet(context);
        if (kind != null) sendAction(PickAttachment(kind));

      case PickAttachment a:
        if (state.chatId.value <= 0 || state.sending.value) return;
        switch (a.kind) {
          case AttachKind.gallery:
            await _attachImage(ImageSource.gallery);
          case AttachKind.camera:
            await _attachImage(ImageSource.camera);
          case AttachKind.file:
            await _attachFile();
          case AttachKind.product:
            await _attachProduct();
          case AttachKind.location:
            await _attachLocation();
          case AttachKind.contact:
            await _attachContact();
        }

      case LongPressMessage a:
        final msg = a.message;
        if (state.selecting.value) {
          sendAction(ToggleSelectMessage(msg));
          return;
        }
        final hasOriginal = msg.textOriginal != null &&
            msg.textOriginal!.isNotEmpty &&
            msg.textOriginal != msg.text;
        final showTranslate =
            msg.type == ChatMsgType.text && !msg.isOutgoing && hasOriginal;
        String? reactedEmoji;
        final chosen = await showMessageActionsDialog(
          context,
          message: msg,
          anchor: a.anchor,
          isGroup: a.isGroup,
          showSenderName: a.showSenderName,
          showAvatar: a.showAvatar,
          showTranslate: showTranslate,
          canPin: !state.isGroup.value ||
              state.myRole == 'owner' ||
              state.myRole == 'admin',
          onReact: (emoji) => reactedEmoji = emoji,
        );
        switch (chosen) {
          case MessageMenuAction.reply:
            sendAction(StartReply(msg));
          case MessageMenuAction.copy:
            sendAction(CopyMessage(msg));
          case MessageMenuAction.delete:
            await _deleteMessageFlow(msg);
          case MessageMenuAction.translate:
            final idx = state.messages.indexWhere((m) => m.id == msg.id);
            if (idx >= 0) {
              state.messages[idx] = msg.withToggleOriginal();
            }
          case MessageMenuAction.edit:
            sendAction(EditMessage(msg));
          case MessageMenuAction.forward:
            _startForward([msg]);
          case MessageMenuAction.pin:
            sendAction(ToggleMessagePin(msg));
          case MessageMenuAction.select:
            sendAction(EnterSelectMode(msg));
          case MessageMenuAction.profile:
            final sid = msg.senderId;
            if (sid != null && sid > 0) {
              sendAction(OpenSenderProfile(sid));
            }
          case MessageMenuAction.react:
            final emoji = reactedEmoji;
            if (emoji != null) sendAction(ReactToMessage(msg, emoji));
          case null:
            break;
        }

      case StartReply a:
        state.replyTo.value = a.message;

      case CancelReply _:
        state.replyTo.value = null;

      case CopyMessage a:
        await Clipboard.setData(ClipboardData(text: a.message.previewText()));
        _toast('chat_copied'.tr);

      case DeleteMessage a:
        await _performDelete(a.message, forEveryone: a.forEveryone);

      case EditMessage a:
        await _editMessageFlow(a.message);

      case ToggleMessagePin a:
        await _togglePin(a.message);

      case ReactToMessage a:
        await _react(a.message, a.emoji);

      case EnterSelectMode a:
        state.selecting.value = true;
        state.selectedIds.clear();
        if (a.seed != null) state.selectedIds.add(a.seed!.id);
        state.selectedIds.refresh();

      case ExitSelectMode _:
        state.selecting.value = false;
        state.selectedIds.clear();
        state.selectedIds.refresh();

      case ToggleSelectMessage a:
        if (state.selectedIds.contains(a.message.id)) {
          state.selectedIds.remove(a.message.id);
        } else {
          state.selectedIds.add(a.message.id);
        }
        state.selectedIds.refresh();
        if (state.selectedIds.isEmpty) {
          state.selecting.value = false;
        }

      case ForwardSelectedMessages _:
        final ids = state.selectedIds.toSet();
        final selected =
            state.messages.where((m) => ids.contains(m.id)).toList();
        _startForward(selected);

      case DeleteSelectedMessages _:
        await _deleteSelectedMessages();

      case CancelForwardDraft _:
        if (Get.isRegistered<ForwardPendingStore>()) {
          Get.find<ForwardPendingStore>().clear();
        }

      case ToggleForwardShowSender _:
        if (Get.isRegistered<ForwardPendingStore>()) {
          Get.find<ForwardPendingStore>().toggleShowSender();
        }


      case OpenChatMenu a:
        final chosen = await showChatOverflowDialog(
          context,
          anchor: a.anchor,
          muted: state.muted.value,
          pinned: state.pinned.value,
          isGroup: state.isGroup.value,
        );
        switch (chosen) {
          case ChatOverflowAction.profile:
            sendAction(OpenPeerProfile());
          case ChatOverflowAction.groupSettings:
            sendAction(OpenGroupSettings());
          case ChatOverflowAction.search:
            break;
          case ChatOverflowAction.mute:
            sendAction(ToggleChatMute());
          case ChatOverflowAction.pin:
            sendAction(ToggleChatPin());
          case ChatOverflowAction.clearHistory:
            sendAction(ClearChatHistory());
          case ChatOverflowAction.deleteChat:
            sendAction(DeleteChat());
          case ChatOverflowAction.block:
            sendAction(BlockPeer());
          case null:
            break;
        }

      case OpenPeerProfile _:
        if (state.isGroup.value) {
          sendAction(OpenGroupSettings());
          return;
        }
        await _openPeerProfile();

      case OpenSenderProfile a:
        await _openUserProfile(a.userId);

      case OpenGroupSettings _:
        await navigate(
          GroupSettingsScreen(),
          payload: GroupSettingsPayload(
            chatId: state.chatId.value,
            title: state.peerName.value,
            avatarUrl: state.peerAvatarUrl.value,
            myRole: state.myRole,
            isSuper: state.isSuper,
            inviteLink: state.inviteLink,
          ),
        );

      case ToggleChatSearch _:
        final next = !state.searching.value;
        state.searching.value = next;
        if (!next) state.searchQuery.value = '';

      case ChatSearchChanged a:
        state.searchQuery.value = a.text;

      case ToggleChatMute _:
        final next = !state.muted.value;
        state.muted.value = next;
        await SessionStore.setChatMuted(state.chatId.value, next);
        if (state.chatId.value > 0) {
          final repo = Get.find<ChatRepository>();
          final result = next
              ? await repo.muteChat(state.chatId.value)
              : await repo.unmuteChat(state.chatId.value);
          if (result.errorOrNull != null) {
            state.muted.value = !next;
            await SessionStore.setChatMuted(state.chatId.value, !next);
            showAppError(result.errorOrNull);
            return;
          }
        }
        _toast(next ? 'chat_muted'.tr : 'chat_unmuted'.tr);

      case ToggleChatPin _:
        if (state.chatId.value <= 0) return;
        final next = !state.pinned.value;
        state.pinned.value = next;
        final repo = Get.find<ChatRepository>();
        final result = next
            ? await repo.pinChat(state.chatId.value)
            : await repo.unpinChat(state.chatId.value);
        if (result.errorOrNull != null) {
          state.pinned.value = !next;
          showAppError(result.errorOrNull);
          return;
        }
        _toast(next ? 'chat_pinned'.tr : 'chat_unpinned'.tr);

      case ClearChatHistory _:
        await _clearHistoryFlow();

      case DeleteChat _:
        final choice = await showTelegramActionSheet(
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
        if (choice != 'delete') return;
        final chatId = state.chatId.value;
        if (chatId > 0) {
          final hide = await Get.find<ChatRepository>().hideChat(chatId);
          if (hide.errorOrNull != null) {
            showAppError(hide.errorOrNull);
            return;
          }
        }
        await _clearHistory(showToast: false, forEveryone: false);
        if (Get.isRegistered<MessagesState>()) {
          Get.find<MessagesState>().conversations.removeWhere((c) => c.id == chatId);
        }
        if (Get.isRegistered<VoiceRecorderService>()) {
          await Get.find<VoiceRecorderService>().cancel();
        }
        if (Get.isRegistered<VoicePlayerService>()) {
          await Get.find<VoicePlayerService>().stop(save: true);
        }
        popBackNavigate();
        _toast('chat_deleted'.tr);

      case BlockPeer _:
        if (state.isGroup.value) return;
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
        if (state.peerId.value > 0) {
          await SessionStore.setUserBlocked(state.peerId.value, true);
          await Get.find<ProfileRepository>().blockUser(state.peerId.value);
          await Get.find<FriendsRepository>().removeFriend(state.peerId.value);
        }
        if (state.chatId.value > 0) {
          await Get.find<ChatRepository>().hideChat(state.chatId.value);
          if (Get.isRegistered<MessagesState>()) {
            Get.find<MessagesState>()
                .conversations
                .removeWhere((c) => c.id == state.chatId.value);
          }
        }
        await _clearHistory(showToast: false, forEveryone: false);
        await Get.find<VoiceRecorderService>().cancel();
        await Get.find<VoicePlayerService>().stop(save: true);
        popBackNavigate();
        _toast('chat_blocked'.tr);

      case OpenChatProduct a:
        await _openChatProduct(a.message);

      case StartRecording _:
        final player = Get.find<VoicePlayerService>();
        if (player.isPlaying.value) await player.stop(save: true);
        final ok = await Get.find<VoiceRecorderService>().start();
        if (!ok) {
          showAppMessage('mic_permission_denied'.tr);
          return;
        }
        state.recording.value = true;
        _sendTyping(state, isTyping: true, activity: 'voice');

      case CancelRecording _:
        await Get.find<VoiceRecorderService>().cancel();
        state.recording.value = false;
        _sendTyping(state, isTyping: false);

      case SendVoice _:
        if (state.sending.value) return;
        final recorded = await Get.find<VoiceRecorderService>().stop();
        state.recording.value = false;
        if (recorded == null || state.chatId.value <= 0) {
          _sendTyping(state, isTyping: false);
          return;
        }

        state.sending.value = true;
        _sendTyping(state, isTyping: true, activity: 'voice');
        final clientId = 'v${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
        final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
        final replyUi = _replyFor(state);
        state.replyTo.value = null;
        final optimistic = ChatMessage.voice(
          id: clientId,
          dir: ChatDir.outgoing,
          time: formatMessageClock(DateTime.now()),
          createdAt: DateTime.now(),
          duration: WaveformUtils.formatDuration(recorded.duration),
          durationMs: recorded.duration.inMilliseconds,
          path: recorded.path,
          samples: recorded.samples,
          status: ChatStatus.sent,
          reply: replyUi,
        );
        state.messages.add(optimistic);

        final upload = await Get.find<ChatRepository>().uploadMedia(
          filePath: recorded.path,
          mediaType: 'voice',
        );
        final uploadMap = asMap(upload.dataOrNull);
        final mediaId = (uploadMap?['id'] as num?)?.toInt();
        if (mediaId == null) {
          state.messages.removeWhere((m) => m.id == optimistic.id);
          final err = upload.errorOrNull;
          if (err != null) {
            showAppError(err);
          } else {
            showAppMessage('voice_upload_failed'.tr);
          }
          _sendTyping(state, isTyping: false);
          state.sending.value = false;
          return;
        }

        final downsampled = WaveformUtils.resampleBars(recorded.samples, 40);
        final send = await Get.find<ChatRepository>().sendVoice(
          chatId: state.chatId.value,
          clientMessageId: clientId,
          mediaId: mediaId,
          meta: {
            'duration_ms': recorded.duration.inMilliseconds,
            'samples': downsampled,
          },
          replyToId: replyToId,
        );
        send.when(
          success: (data) {
            final map = asMap(data);
            if (map == null) return;
            final real = _fromApi(
              map,
              SessionStore.userId(),
              fallbackReply: replyUi,
            );
            final merged = ChatMessage.voice(
              id: real.id,
              dir: real.dir,
              time: real.time,
              createdAt: real.createdAt,
              duration: optimistic.voiceDuration ?? real.voiceDuration ?? '0:00',
              durationMs: optimistic.voiceDurationMs ?? real.voiceDurationMs,
              path: optimistic.voicePath ?? real.voicePath,
              samples: optimistic.voiceSamples.isNotEmpty
                  ? optimistic.voiceSamples
                  : real.voiceSamples,
              status: real.status,
              reply: real.reply ?? replyUi,
              senderId: real.senderId,
              senderName: real.senderName,
              senderAvatarUrl: real.senderAvatarUrl,
            );
            final idx = state.messages.indexWhere((m) => m.id == clientId || m.id == real.id);
            if (idx >= 0) state.messages[idx] = merged;
          },
          failure: (err) {
            state.messages.removeWhere((m) => m.id == clientId);
            showAppError(err);
          },
        );
        _sendTyping(state, isTyping: false);
        state.sending.value = false;

      case Back _:
        _typingDebounce?.cancel();
        _sendTyping(state, isTyping: false);
        if (state.selecting.value) {
          sendAction(ExitSelectMode());
          return;
        }
        if (state.searching.value) {
          state.searching.value = false;
          state.searchQuery.value = '';
          return;
        }
        if (Get.isRegistered<RealtimeSyncService>()) {
          Get.find<RealtimeSyncService>().setActiveChat(null);
        }
        // Open chat'dan chiqganda unread tozalangan ko‘rinsin.
        if (Get.isRegistered<MessagesState>() && state.chatId.value > 0) {
          final ms = Get.find<MessagesState>();
          final list = ms.conversations.toList();
          final i = list.indexWhere((c) => c.id == state.chatId.value);
          if (i >= 0 && list[i].unread > 0) {
            list[i] = list[i].copyWith(unread: 0, highlighted: false);
            ms.conversations.assignAll(list);
          }
        }
        await Get.find<VoiceRecorderService>().cancel();
        await Get.find<VoicePlayerService>().stop(save: true);
        popBackNavigate();
    }
  }

  Future<void> _openPeerProfile() async {
    await _openUserProfile(state.peerId.value);
  }

  Future<void> _openUserProfile(int userId) async {
    if (userId <= 0) {
      showAppWarning('chat_profile_unavailable'.tr);
      return;
    }
    final result = await Get.find<ProfileRepository>().getPublicUser(userId);
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
  }

  bool _isGroupAdmin() =>
      state.myRole == 'owner' || state.myRole == 'admin';

  /// Telegram: DM da hammaga; guruhda o'z xabari yoki admin.
  bool _canDeleteMessageForEveryone(ChatMessage msg) {
    if (!state.isGroup.value) return true;
    if (msg.isOutgoing) return true;
    return _isGroupAdmin();
  }

  Future<void> _clearHistoryFlow() async {
    final isGroup = state.isGroup.value;
    final canEveryone = !isGroup || _isGroupAdmin();
    final body = !isGroup
        ? 'chat_clear_body_dm'.tr
        : (canEveryone
            ? 'chat_clear_body_group_admin'.tr
            : 'chat_clear_body_group'.tr);
    final actions = <TelegramSheetAction>[
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
    ];
    final choice = await showTelegramActionSheet(
      context,
      title: 'chat_clear_title'.tr,
      body: body,
      actions: actions,
    );
    if (choice == null) return;
    await _clearHistory(
      showToast: true,
      forEveryone: choice == 'everyone',
    );
  }

  Future<void> _clearHistory({
    required bool showToast,
    bool forEveryone = false,
  }) async {
    state.messages.clear();
    state.replyTo.value = null;
    state.pinnedBanner.value = null;
    if (state.chatId.value > 0) {
      final result = await Get.find<ChatRepository>().clearHistory(
        state.chatId.value,
        forEveryone: forEveryone,
      );
      result.when(
        success: (_) {},
        failure: showAppError,
      );
    }
    if (showToast) _toast('chat_history_cleared'.tr);
  }

  void _startForward(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    if (!Get.isRegistered<ForwardPendingStore>()) return;
    Get.find<ForwardPendingStore>().beginFromMessages(
      sourceChatId: state.chatId.value,
      messages: messages,
      peerName: state.peerName.value,
      youLabel: 'chat_you'.tr,
    );
    state.selecting.value = false;
    state.selectedIds.clear();
    state.selectedIds.refresh();
    if (Get.isRegistered<MainState>()) {
      Get.find<MainState>().currentTab.value = 0;
    }
    showAppMessage('chat_forward_pick'.tr);
    _typingDebounce?.cancel();
    _sendTyping(state, isTyping: false);
    if (Get.isRegistered<RealtimeSyncService>()) {
      final sync = Get.find<RealtimeSyncService>();
      final bound = _boundChatId;
      if (bound != null && sync.activeChatId == bound) {
        sync.setActiveChat(null);
      }
    }
    popBackNavigate();
  }

  Future<void> _sendComposer(ChatState state) async {
    final fwd = Get.isRegistered<ForwardPendingStore>()
        ? Get.find<ForwardPendingStore>()
        : null;
    final hasFwd = fwd?.hasPending == true;
    final text = state.input.value.trim();
    if (text.isEmpty && !hasFwd) return;
    if (state.chatId.value <= 0) {
      showAppError('chat_send_unavailable'.tr);
      return;
    }
    if (state.sending.value) return;
    state.sending.value = true;
    try {
      if (hasFwd) {
        final ok = await _sendPendingForwards(state);
        if (!ok) return;
      }
      if (text.isNotEmpty) {
        await _sendPlainText(state, text);
      }
    } finally {
      state.sending.value = false;
    }
  }

  Future<bool> _sendPendingForwards(ChatState state) async {
    final store = Get.find<ForwardPendingStore>();
    final items = store.items.toList();
    if (items.isEmpty) return true;
    final hideSender = !store.showSender.value;
    final repo = Get.find<ChatRepository>();
    final targetChatId = state.chatId.value;
    var failed = false;
    for (final item in items) {
      final result = await repo.forwardMessage(
        item.messageId,
        chatIds: [targetChatId],
        hideSender: hideSender,
      );
      result.when(
        success: (data) {
          final map = asMap(data);
          final list = (map?['items'] as List?) ?? const [];
          for (final raw in list) {
            if (raw is! Map) continue;
            final real = _fromApi(
              Map<String, dynamic>.from(raw),
              SessionStore.userId(),
            );
            final idx = state.messages.indexWhere((m) => m.id == real.id);
            if (idx >= 0) {
              state.messages[idx] = real;
            } else {
              state.messages.add(real);
            }
          }
        },
        failure: (err) {
          failed = true;
          showAppError(err);
        },
      );
      if (failed) break;
    }
    if (!failed) {
      store.clear();
      _toast('chat_forward_sent'.tr);
    }
    return !failed;
  }

  Future<void> _sendPlainText(ChatState state, String text) async {
    final clientId = 'c${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
    final replyUi = _replyFor(state);
    final optimistic = ChatMessage.text(
      id: clientId,
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      text: text,
      status: ChatStatus.sent,
      reply: replyUi,
    );
    state.messages.add(optimistic);
    state.input.value = '';
    state.replyTo.value = null;
    _sendTyping(state, isTyping: false);

    final result = await Get.find<ChatRepository>().sendText(
      chatId: state.chatId.value,
      text: text,
      clientMessageId: clientId,
      replyToId: replyToId,
    );
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) {
          showAppError('chat_send_failed'.tr);
          return;
        }
        final real = _fromApi(
          map,
          SessionStore.userId(),
          fallbackReply: replyUi,
        );
        final idx = state.messages.indexWhere(
          (m) => m.id == clientId || m.id == real.id,
        );
        if (idx >= 0) {
          state.messages[idx] = real;
        } else {
          state.messages.add(real);
        }
      },
      failure: (err) {
        state.messages.removeWhere(
          (m) => m.id == clientId || m.id == optimistic.id,
        );
        state.input.value = text;
        showAppError(err);
      },
    );
  }

  Future<void> _deleteMessageFlow(ChatMessage msg) async {
    final canEveryone = _canDeleteMessageForEveryone(msg);
    final actions = <TelegramSheetAction>[
      if (canEveryone)
        TelegramSheetAction(
          id: 'everyone',
          label: 'chat_msg_delete_everyone'.tr,
          danger: true,
        ),
      TelegramSheetAction(
        id: 'me',
        label: 'chat_msg_delete_me'.tr,
        danger: true,
      ),
    ];
    final choice = await showTelegramActionSheet(
      context,
      title: 'chat_msg_delete_title'.tr,
      body: 'chat_msg_delete_choose'.tr,
      actions: actions,
    );
    if (choice == null) return;
    await _performDelete(msg, forEveryone: choice == 'everyone');
  }

  Future<void> _deleteSelectedMessages() async {
    final ids = state.selectedIds.toSet();
    if (ids.isEmpty) return;
    final selected = state.messages.where((m) => ids.contains(m.id)).toList();
    if (selected.isEmpty) return;

    final canEveryone = !state.isGroup.value ||
        _isGroupAdmin() ||
        selected.every((m) => m.isOutgoing);

    final actions = <TelegramSheetAction>[
      if (canEveryone)
        TelegramSheetAction(
          id: 'everyone',
          label: 'chat_msg_delete_everyone'.tr,
          danger: true,
        ),
      TelegramSheetAction(
        id: 'me',
        label: 'chat_msg_delete_me'.tr,
        danger: true,
      ),
    ];
    final choice = await showTelegramActionSheet(
      context,
      title: selected.length == 1
          ? 'chat_msg_delete_title'.tr
          : 'chat_msg_delete_title_n'.trParams({'n': '${selected.length}'}),
      body: 'chat_msg_delete_choose'.tr,
      actions: actions,
    );
    if (choice == null) return;

    final forEveryone = choice == 'everyone';
    final snapshot = List<ChatMessage>.from(selected);
    final toDelete = forEveryone && state.isGroup.value && !_isGroupAdmin()
        ? snapshot.where((m) => m.isOutgoing).toList()
        : snapshot;
    if (toDelete.isEmpty) return;
    final deleteIds = toDelete.map((m) => m.id).toSet();
    state.messages.removeWhere((m) => deleteIds.contains(m.id));
    if (state.replyTo.value != null &&
        deleteIds.contains(state.replyTo.value!.id)) {
      state.replyTo.value = null;
    }
    state.selecting.value = false;
    state.selectedIds.clear();
    state.selectedIds.refresh();

    final repo = Get.find<ChatRepository>();
    for (final msg in toDelete) {
      final id = int.tryParse(msg.id);
      if (id == null) continue;
      final result = await repo.deleteMessage(id, forEveryone: forEveryone);
      result.when(
        success: (_) {},
        failure: (err) {
          state.messages.add(msg);
          state.messages.sort((a, b) {
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return at.compareTo(bt);
          });
          showAppError(err);
        },
      );
    }
  }

  Future<void> _performDelete(
    ChatMessage msg, {
    required bool forEveryone,
  }) async {
    final id = int.tryParse(msg.id);
    final idx = state.messages.indexWhere((m) => m.id == msg.id);
    state.messages.removeWhere((m) => m.id == msg.id);
    if (state.replyTo.value?.id == msg.id) {
      state.replyTo.value = null;
    }
    if (id != null) {
      final result = await Get.find<ChatRepository>().deleteMessage(
        id,
        forEveryone: forEveryone,
      );
      result.when(
        success: (_) {},
        failure: (err) {
          final insertAt =
              idx >= 0 ? idx.clamp(0, state.messages.length) : state.messages.length;
          state.messages.insert(insertAt, msg);
          showAppError(err);
        },
      );
    }
  }

  Future<void> _editMessageFlow(ChatMessage msg) async {
    final ctrl = TextEditingController(text: msg.displayText);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('chat_menu_edit'.tr),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('common_save'.tr),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    final id = int.tryParse(msg.id);
    if (id == null) return;
    final result =
        await Get.find<ChatRepository>().editMessage(id, text: next);
    result.when(
      success: (_) {
        final idx = state.messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) {
          state.messages[idx] = msg.withEditedText(next);
        }
      },
      failure: showAppError,
    );
  }

  Future<void> _togglePin(ChatMessage msg) async {
    final id = int.tryParse(msg.id);
    if (id == null || state.chatId.value <= 0) return;
    final repo = Get.find<ChatRepository>();
    final result = msg.pinned
        ? await repo.unpinMessage(state.chatId.value, id)
        : await repo.pinMessage(state.chatId.value, id);
    result.when(
      success: (_) {
        final idx = state.messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) {
          state.messages[idx] = msg.withPinned(!msg.pinned);
        }
        if (!msg.pinned) {
          state.pinnedBanner.value = msg.withPinned(true);
        } else if (state.pinnedBanner.value?.id == msg.id) {
          state.pinnedBanner.value = null;
        }
      },
      failure: showAppError,
    );
  }

  Future<void> _react(ChatMessage msg, String emoji) async {
    final id = int.tryParse(msg.id);
    if (id == null) return;
    final result =
        await Get.find<ChatRepository>().setReaction(id, emoji: emoji);
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final reactions = (map['reactions'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const <Map<String, dynamic>>[];
        final idx = state.messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) {
          state.messages[idx] = msg.withReactions(reactions);
        }
      },
      failure: showAppError,
    );
  }

  String _nextId() => 'm${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _handleTyping(ChatState state, String text) {
    if (state.chatId.value <= 0 || !Get.isRegistered<SocketService>()) return;
    if (text.isEmpty) {
      _typingDebounce?.cancel();
      _sendTyping(state, isTyping: false);
      return;
    }
    // Birinchi belgi — darhol typing; keyin keep-alive debounced.
    if (!_lastTypingSent) {
      _sendTyping(state, isTyping: true, activity: 'typing');
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 2500), () {
      _sendTyping(state, isTyping: false);
    });
  }

  void _sendTyping(
    ChatState state, {
    required bool isTyping,
    String activity = 'typing',
  }) {
    if (state.chatId.value <= 0 || !Get.isRegistered<SocketService>()) return;
    if (!isTyping && !_lastTypingSent) return;
    Get.find<SocketService>().sendRaw({
      'type': 'typing',
      'data': {
        'chat_id': state.chatId.value,
        'is_typing': isTyping,
        if (isTyping) 'activity': activity,
      },
    });
    _lastTypingSent = isTyping;
  }

  ChatReply? _replyFor(ChatState state) {
    final r = state.replyTo.value;
    if (r == null) return null;
    return ChatReply(
      author: r.isOutgoing ? 'chat_you'.tr : state.peerName.value,
      preview: r.previewText(),
      messageId: r.id,
    );
  }

  Future<void> _attachImage(ImageSource source) async {
    final file = await pickImage(context, source: source);
    if (file == null) return;
    final optimistic = ChatMessage.image(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      url: file.path,
      gradient: avatarTealGradient,
      status: ChatStatus.sent,
      reply: _replyFor(state),
    );
    await _uploadAndSendMedia(
      filePath: file.path,
      mediaType: 'image',
      messageType: 'image',
      optimistic: optimistic,
    );
  }

  Future<void> _attachFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      showAppMessage('Fayl ochilmadi');
      return;
    }
    final name = file.name;
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'FILE';
    final optimistic = ChatMessage.file(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      name: name,
      size: file.size > 0 ? _formatBytes(file.size) : '—',
      ext: ext,
      status: ChatStatus.sent,
    );
    await _uploadAndSendMedia(
      filePath: path,
      mediaType: 'file',
      messageType: 'file',
      optimistic: optimistic,
      extraMeta: {'filename': name, if (file.size > 0) 'size': file.size},
    );
  }

  Future<void> _attachProduct() async {
    final product = await _pickProduct();
    if (product == null) return;
    final optimistic = ChatMessage.product(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      title: product.name,
      price: product.price,
      productId: product.id,
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'product',
      meta: {
        'product_id': product.id,
        'name': product.name,
        'price': product.price,
        if (product.imageUrl != null) 'image_url': product.imageUrl,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _attachLocation() async {
    if (!context.mounted) return;
    final picked = await showLocationPickerBottomSheet(context);
    if (picked == null) return;
    final label = picked.label.trim().isNotEmpty
        ? picked.label.trim()
        : 'chat_my_location'.tr;
    final optimistic = ChatMessage.location(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      label: label,
      distance: picked.accuracyMeters != null
          ? '~${picked.accuracyMeters!.round()} m'
          : '',
      latitude: picked.latitude,
      longitude: picked.longitude,
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'location',
      meta: {
        'latitude': picked.latitude,
        'longitude': picked.longitude,
        'label': label,
        if (picked.accuracyMeters != null)
          'accuracy_m': picked.accuracyMeters,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _attachContact() async {
    final contact = await _pickContact();
    if (contact == null) return;
    final name = contact.$1;
    final phone = contact.$2;
    final optimistic = ChatMessage.contact(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      name: name,
      phone: phone,
      initial: initialsOf(name),
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'contact',
      meta: {
        'contact_name': name,
        'contact_phone': phone,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _uploadAndSendMedia({
    required String filePath,
    required String mediaType,
    required String messageType,
    required ChatMessage optimistic,
    Map<String, dynamic>? extraMeta,
  }) async {
    if (state.sending.value || state.chatId.value <= 0) return;
    state.sending.value = true;
    final activity = switch (messageType) {
      'image' => 'photo',
      'voice' || 'audio' => 'voice',
      'video' => 'video',
      _ => 'file',
    };
    _sendTyping(state, isTyping: true, activity: activity);
    final clientId = 'a${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
    final replyUi = optimistic.reply ?? _replyFor(state);
    state.replyTo.value = null;
    // Optimistic id = clientId — WS echo bilan merge ishlasin.
    final optimisticRow = switch (optimistic.type) {
      ChatMsgType.image => ChatMessage.image(
          id: clientId,
          dir: optimistic.dir,
          time: optimistic.time,
          createdAt: optimistic.createdAt,
          url: optimistic.imageUrl,
          gradient: avatarTealGradient,
          status: optimistic.status,
          reply: replyUi,
        ),
      ChatMsgType.file => ChatMessage.file(
          id: clientId,
          dir: optimistic.dir,
          time: optimistic.time,
          createdAt: optimistic.createdAt,
          name: optimistic.fileName ?? 'file',
          size: optimistic.fileSize ?? '—',
          ext: optimistic.fileExt ?? 'FILE',
          url: optimistic.fileUrl,
          status: optimistic.status,
        ),
      _ => optimistic,
    };
    state.messages.add(optimisticRow);

    final repo = Get.find<ChatRepository>();
    final upload = await repo.uploadMedia(
      filePath: filePath,
      mediaType: mediaType,
    );
    final uploadMap = asMap(upload.dataOrNull);
    final mediaId = (uploadMap?['id'] as num?)?.toInt();
    if (mediaId == null) {
      state.messages.removeWhere((m) => m.id == optimisticRow.id);
      final err = upload.errorOrNull;
      if (err != null) {
        showAppError(err);
      } else {
        showAppMessage('Fayl yuklanmadi');
      }
      _sendTyping(state, isTyping: false);
      state.sending.value = false;
      return;
    }

    final send = await repo.sendMessage(
      chatId: state.chatId.value,
      clientMessageId: clientId,
      type: messageType,
      mediaId: mediaId,
      meta: extraMeta,
      replyToId: replyToId,
    );
    send.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final real = _fromApi(
          map,
          SessionStore.userId(),
          fallbackReply: replyUi,
        );
        final idx = state.messages.indexWhere((m) => m.id == clientId || m.id == real.id);
        if (idx >= 0) {
          // Lokal fayl yo‘li bo‘lsa, tarmoq URL kelguncha saqlaymiz.
          if (optimisticRow.type == ChatMsgType.image &&
              (real.imageUrl == null || real.imageUrl!.isEmpty) &&
              optimisticRow.imageUrl != null) {
            state.messages[idx] = ChatMessage.image(
              id: real.id,
              dir: real.dir,
              time: real.time,
              createdAt: real.createdAt,
              url: optimisticRow.imageUrl,
              gradient: avatarTealGradient,
              status: real.status,
              reply: real.reply ?? replyUi,
              senderId: real.senderId,
              senderName: real.senderName,
              senderAvatarUrl: real.senderAvatarUrl,
            );
          } else {
            state.messages[idx] = real;
          }
        }
      },
      failure: (err) {
        state.messages.removeWhere((m) => m.id == clientId);
        showAppError(err);
      },
    );
    _sendTyping(state, isTyping: false);
    state.sending.value = false;
  }

  Future<void> _sendMetaMessage({
    required String type,
    required Map<String, dynamic> meta,
    required ChatMessage optimistic,
  }) async {
    if (state.sending.value || state.chatId.value <= 0) return;
    state.sending.value = true;
    final clientId = 'a${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
    state.replyTo.value = null;
    state.messages.add(optimistic);

    final send = await Get.find<ChatRepository>().sendMessage(
      chatId: state.chatId.value,
      clientMessageId: clientId,
      type: type,
      meta: meta,
      replyToId: replyToId,
    );
    send.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final real = _fromApi(map, SessionStore.userId());
        final idx = state.messages.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) state.messages[idx] = real;
      },
      failure: (err) {
        state.messages.removeWhere((m) => m.id == optimistic.id);
        showAppError(err);
      },
    );
    state.sending.value = false;
  }

  Future<Product?> _pickProduct() async {
    final result = await Get.find<ProductsRepository>().list(limit: 40);
    final items = asList(result.dataOrNull)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .toList();
    if (items.isEmpty) {
      if (result.errorOrNull != null) {
        showAppError(result.errorOrNull!);
      } else {
        showAppMessage('Mahsulot topilmadi');
      }
      return null;
    }
    if (!context.mounted) return null;
    return showModalBottomSheet<Product>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final c = ctx.appColors;
        final inset = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
            ),
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 8.dp),
                  child: Column(
                    children: [
                      Container(
                        width: 44.dp,
                        height: 5.dp,
                        decoration: BoxDecoration(
                          color: c.outline,
                          borderRadius: BorderRadius.circular(5.dp),
                        ),
                      ),
                      SizedBox(height: 14.dp),
                      Text(
                        'chat_attach_product'.tr,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 16.dp),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(height: 4.dp),
                    itemBuilder: (_, i) {
                      final p = items[i];
                      return ListTile(
                        title: Text(
                          p.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          p.price,
                          style: TextStyle(color: c.textSecondary),
                        ),
                        onTap: () => Navigator.pop(ctx, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<(String, String)?> _pickContact() async {
    final user = SessionStore.user();
    final nameCtrl = TextEditingController(
      text: user?['full_name']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: user?['phone']?.toString() ?? '',
    );
    if (!context.mounted) return null;
    final c = context.appColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        title: Text(
          'chat_attach_contact'.tr,
          style: TextStyle(color: c.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'full_name'.tr,

                labelStyle: TextStyle(color: c.textSecondary),
              ),
              style: TextStyle(color: c.textPrimary),
            ),
            SizedBox(height: 12.dp),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'profile_phone'.tr,
                labelStyle: TextStyle(color: c.textSecondary),
              ),
              style: TextStyle(color: c.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('chat_contact_send'.tr),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (ok != true || name.isEmpty) return null;
    return (name, phone);
  }

  Future<void> _openChatProduct(ChatMessage msg) async {
    final id = msg.productId;
    if (id == null || id <= 0) return;
    final result = await Get.find<ProductsRepository>().detail(id);
    final map = asMap(result.dataOrNull);
    if (map == null) {
      if (result.errorOrNull != null) showAppError(result.errorOrNull!);
      return;
    }
    final product = Product.fromApi(map);
    if (!context.mounted) return;
    await showProductInfoBottomSheet(
      context,
      product,
      onOpenBusiness: () async {
        if (product.sellerId <= 0) return;
        final profile =
            await Get.find<ProfileRepository>().getPublicUser(product.sellerId);
        profile.when(
          success: (data) {
            final profileMap = asMap(data);
            if (profileMap == null) return;
            navigate(
              UserProfileScreen(),
              payload: UserProfilePayload.fromApi(profileMap),
            );
          },
          failure: showAppError,
        );
      },
    );
  }

  void _toast(String msg) => showAppMessage(msg);
}
