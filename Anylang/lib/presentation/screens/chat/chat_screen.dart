import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/audio/voice_player_service.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/audio/waveform_utils.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/offline_chat_store.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/connectivity_service.dart';
import '../../../data/network/forward_pending_store.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/invite_deep_link_service.dart';
import '../../../data/network/offline_outbox_service.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/realtime_sync_service.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../../data/network/socket_service.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../modal/attachment_bottom_sheet.dart';
import '../../modal/invoice_compose_bottom_sheet.dart';
import '../../modal/offer_compose_bottom_sheet.dart';
import '../../modal/rfq_compose_bottom_sheet.dart';
import '../../modal/location_picker_bottom_sheet.dart';
import '../../modal/chat_overflow_dialog.dart';
import '../../modal/chat_overflow_sheet.dart';
import '../../modal/chat_mute_duration_bottom_sheet.dart';
import '../../modal/chat_summary_bottom_sheet.dart';
import '../../modal/chat_video_picker.dart';
import '../../modal/image_picker.dart';
import '../../modal/message_actions_dialog.dart';
import '../../modal/share_contact_bottom_sheet.dart';
import '../../modal/shared_media_bottom_sheet.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../group_settings/group_settings_payload.dart';
import '../group_settings/group_settings_screen.dart';
import '../group_catalog/group_catalog_payload.dart';
import '../group_catalog/group_catalog_screen.dart';
import '../group_stats/group_stats_payload.dart';
import '../group_stats/group_stats_screen.dart';
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
import 'chat_state_scope.dart';

class ChatScreen extends Screen<ChatState, ChatPayload> {
  ChatScreen()
      : super(
          mobileContent: ChatContent(),
          createState: ChatState.new,
        );

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
    ChatStateScope.attach(state);
    state.bindPayload(p);
    _boundChatId = p.chatId;
    state.muted.value = SessionStore.isChatMuted(p.chatId);
    if (Get.isRegistered<RealtimeSyncService>()) {
      Get.find<RealtimeSyncService>().setActiveChat(p.chatId);
    }
    // Real-time: WS ulangani va tinglovchi qayta bog'langani shart.
    unawaited(connectRealtimeIfNeeded());
    if (Get.isRegistered<OfflineOutboxService>()) {
      unawaited(Get.find<OfflineOutboxService>().flush());
    }
    final session = state.sessionId.value;
    _loadMessages(p.chatId, session);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    final bound = _boundChatId;
    ChatStateScope.pop(state);
    if (Get.isRegistered<RealtimeSyncService>()) {
      final sync = Get.find<RealtimeSyncService>();
      // Keyingi chat ochilganda dispose keyinroq kelishi mumkin —
      // faqat hali shu chat active bo'lsa tozalaymiz / pastdagini tiklaymiz.
      if (bound != null && sync.activeChatId == bound) {
        final below = ChatStateScope.currentOrNull;
        sync.setActiveChat(
          below != null && below.chatId.value > 0 ? below.chatId.value : null,
        );
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
        unawaited(OfflineChatStore.saveMessages(chatId, raw));
        final items = raw.map((e) => _fromApi(e, me)).toList();
        final filled = _fillMissingReplies(items, raw, me);
        final pendingLocal = _pendingMessagesFromOutbox(chatId);
        // Faqat shu chatga tegishli live xabarlarni saqlab qolamiz.
        final liveOnly = state.messages
            .where((m) => filled.every((f) => f.id != m.id))
            .where((m) => pendingLocal.every((p) => p.id != m.id))
            .toList();
        final merged = [...filled, ...pendingLocal, ...liveOnly]
          ..sort((a, b) {
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return at.compareTo(bt);
          });
        state.messages.assignAll(merged);
        state.loadError.value = false;
        if (state.searching.value &&
            state.searchQuery.value.trim().isNotEmpty) {
          _recomputeSearchMatches(state);
        }
        final pinned = merged.where((m) => m.pinned).toList();
        state.pinnedMessages.assignAll(pinned);
        state.pinnedBanner.value = pinned.isNotEmpty ? pinned.last : null;
        final ids = filled
            .where((m) => !m.isOutgoing)
            .map((m) => int.tryParse(m.id))
            .whereType<int>()
            .toList();
        if (ids.isNotEmpty) {
          unawaited(_markReadSafe(chatId, ids));
        }
        if (chatId > 0) {
          unawaited(_loadPinned(chatId, session));
        }
      },
      failure: (err) {
        if (state.sessionId.value != session || state.chatId.value != chatId) {
          return;
        }
        final cached = OfflineChatStore.loadMessages(chatId);
        final pendingLocal = _pendingMessagesFromOutbox(chatId);
        if (cached.isNotEmpty || pendingLocal.isNotEmpty) {
          final me = SessionStore.userId();
          final items = cached.map((e) => _fromApi(e, me)).toList();
          final merged = [...items, ...pendingLocal]
            ..sort((a, b) {
              final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return at.compareTo(bt);
            });
          state.messages.assignAll(merged);
          return;
        }
        state.loadError.value = true;
        if (!isNetworkFailure(err)) {
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
        final me = SessionStore.userId();
        final mapped = items
            .map(
              (e) => mapChatMessageFromApi(
                e,
                me: me,
                peerName: state.peerName.value,
              ).withPinned(true),
            )
            .toList()
            .reversed
            .toList();
        state.pinnedMessages.assignAll(mapped);
        state.pinnedBanner.value = mapped.isNotEmpty ? mapped.last : null;
      },
      failure: (err) {
        state.pinnedMessages.clear();
        state.pinnedBanner.value = null;
        debugPrint('pinned load failed: $err');
      },
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

  List<ChatMessage> _pendingMessagesFromOutbox(int chatId) {
    final out = <ChatMessage>[];
    for (final e in OfflineChatStore.outboxForChat(chatId)) {
      final id = e['client_message_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final created = DateTime.tryParse(e['created_at']?.toString() ?? '');
      final kind = e['kind']?.toString() ?? 'text';
      if (kind == 'voice') {
        final samples = (e['samples'] as List?)
                ?.whereType<num>()
                .map((n) => n.toDouble())
                .toList() ??
            const <double>[];
        final ms = (e['duration_ms'] as num?)?.toInt() ?? 0;
        out.add(
          ChatMessage.voice(
            id: id,
            dir: ChatDir.outgoing,
            time: formatMessageClock(created),
            createdAt: created,
            duration: WaveformUtils.formatDuration(Duration(milliseconds: ms)),
            durationMs: ms,
            path: e['file_path']?.toString(),
            samples: samples,
            status: ChatStatus.pending,
            transcriptPending: true,
          ),
        );
      } else if (kind == 'text') {
        out.add(
          ChatMessage.text(
            id: id,
            dir: ChatDir.outgoing,
            time: formatMessageClock(created),
            createdAt: created,
            text: e['text']?.toString() ?? '',
            status: ChatStatus.pending,
          ),
        );
      } else {
        // image/file/video — lokal path bilan pending
        final path = e['file_path']?.toString();
        if (kind == 'image') {
          out.add(
            ChatMessage.image(
              id: id,
              dir: ChatDir.outgoing,
              time: formatMessageClock(created),
              createdAt: created,
              url: path,
              status: ChatStatus.pending,
            ),
          );
        } else {
          out.add(
            ChatMessage.file(
              id: id,
              dir: ChatDir.outgoing,
              time: formatMessageClock(created),
              createdAt: created,
              name: e['file_name']?.toString() ?? 'file',
              size: e['file_size']?.toString() ?? '—',
              ext: e['file_ext']?.toString() ?? 'FILE',
              url: path,
              status: ChatStatus.pending,
            ),
          );
        }
      }
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
        text: msg.text,
        textOriginal: msg.textOriginal,
        showingOriginal: msg.showingOriginal,
        transcriptPending: msg.transcriptPending,
        transcriptFailed: msg.transcriptFailed,
      );
    }
    if (msg.type == ChatMsgType.video) {
      return ChatMessage.video(
        id: msg.id,
        dir: msg.dir,
        time: msg.time,
        createdAt: msg.createdAt,
        url: msg.videoUrl,
        isRoundNote: msg.isRoundNote,
        duration: msg.videoDuration,
        durationMs: msg.videoDurationMs,
        status: msg.status,
        reply: reply,
        senderId: msg.senderId,
        senderName: msg.senderName,
        senderAvatarUrl: msg.senderAvatarUrl,
        text: msg.text,
        textOriginal: msg.textOriginal,
        showingOriginal: msg.showingOriginal,
        transcriptPending: msg.transcriptPending,
        transcriptFailed: msg.transcriptFailed,
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
        final kind = await showAttachmentBottomSheet(
          context,
          showRfq: state.isMarketplace,
        );
        if (kind != null) sendAction(PickAttachment(kind));

      case PickAttachment a:
        if (state.chatId.value <= 0 || state.sending.value) return;
        switch (a.kind) {
          case AttachKind.gallery:
            await _attachImage(ImageSource.gallery);
          case AttachKind.camera:
            await _attachImage(ImageSource.camera);
          case AttachKind.video:
            await _attachVideo(roundNote: false);
          case AttachKind.roundVideo:
            await _attachVideo(roundNote: true);
          case AttachKind.file:
            await _attachFile();
          case AttachKind.product:
            await _attachProduct();
          case AttachKind.location:
            await _attachLocation();
          case AttachKind.contact:
            await _attachContact();
          case AttachKind.invoice:
            await _attachInvoice();
          case AttachKind.offer:
            await _attachOffer();
          case AttachKind.rfq:
            await _attachRfq();
          case AttachKind.catalog:
            await _attachCatalog();
          case AttachKind.businessCard:
            await _attachBusinessCard();
        }

      case SuggestAiReply a:
        await _suggestAiReply(a.message, tone: a.tone);
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
          case ChatOverflowAction.groupCatalog:
            sendAction(OpenGroupCatalog());
          case ChatOverflowAction.groupStats:
            sendAction(OpenGroupStats());
          case ChatOverflowAction.sharedMedia:
            sendAction(OpenSharedMedia());
          case ChatOverflowAction.search:
            sendAction(ToggleChatSearch());
          case ChatOverflowAction.mute:
            sendAction(ToggleChatMute());
          case ChatOverflowAction.pin:
            sendAction(ToggleChatPin());
          case ChatOverflowAction.aiSummary:
            await _showAiSummary();
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
        if (state.isSaved.value) {
          sendAction(OpenSharedMedia());
          return;
        }
        if (state.isGroup.value) {
          sendAction(OpenGroupSettings());
          return;
        }
        await _openPeerProfile();

      case OpenSenderProfile a:
        await _openUserProfile(a.userId);

      case JoinGroupInvite a:
        await Get.find<InviteDeepLinkService>().openInvite(
          a.token,
          context: context,
        );

      case OpenSharedContactChat a:
        await _openSharedContactChat(a.message);

      case AddSharedContact a:
        await _addSharedContact(a.message);

      case AcceptOffer a:
        await _acceptOffer(a.message);

      case CounterOffer a:
        await _counterOffer(a.message);

      case ReplyToRfq a:
        await _replyToRfq(a.message);

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

      case OpenGroupCatalog a:
        if (!state.isGroup.value || state.chatId.value <= 0) return;
        await navigate(
          GroupCatalogScreen(),
          payload: GroupCatalogPayload(
            chatId: state.chatId.value,
            title: state.peerName.value,
            initialSection: a.section,
          ),
        );

      case OpenGroupStats _:
        if (!state.isGroup.value || state.chatId.value <= 0) return;
        await navigate(
          GroupStatsScreen(),
          payload: GroupStatsPayload(
            chatId: state.chatId.value,
            title: state.peerName.value,
          ),
        );

      case OpenSharedMedia _:
        if (state.chatId.value <= 0) return;
        await showSharedMediaBottomSheet(
          context,
          chatId: state.chatId.value,
          title: state.isSaved.value
              ? 'saved_messages_title'.tr
              : state.peerName.value,
        );

      case ToggleChatSearch _:
        final next = !state.searching.value;
        state.searching.value = next;
        if (!next) {
          state.searchQuery.value = '';
          state.searchMatchIds.clear();
          state.searchMatchIndex.value = 0;
        }

      case ChatSearchChanged a:
        state.searchQuery.value = a.text;
        _recomputeSearchMatches(state);

      case ChatSearchPrev _:
        _moveSearchMatch(state, -1);

      case ChatSearchNext _:
        _moveSearchMatch(state, 1);

      case ToggleChatMute _:
        if (state.muted.value) {
          state.muted.value = false;
          await SessionStore.setChatMuted(state.chatId.value, false);
          if (state.chatId.value > 0) {
            final result =
                await Get.find<ChatRepository>().unmuteChat(state.chatId.value);
            if (result.errorOrNull != null) {
              state.muted.value = true;
              await SessionStore.setChatMuted(state.chatId.value, true);
              showAppError(result.errorOrNull);
              return;
            }
          }
          _toast('chat_unmuted'.tr);
        } else {
          if (!context.mounted) return;
          final choice = await showChatMuteDurationBottomSheet(context);
          if (choice == null) return;
          final dur = choice.asDuration;
          state.muted.value = true;
          await SessionStore.setChatMuted(
            state.chatId.value,
            true,
            duration: dur,
          );
          if (state.chatId.value > 0) {
            final result = await Get.find<ChatRepository>().muteChat(
              state.chatId.value,
              durationSeconds: choice.durationSeconds,
            );
            if (result.errorOrNull != null) {
              state.muted.value = false;
              await SessionStore.setChatMuted(state.chatId.value, false);
              showAppError(result.errorOrNull);
              return;
            }
          }
          _toast(choice.toastKey.tr);
        }

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
        final online = Get.isRegistered<ConnectivityService>()
            ? Get.find<ConnectivityService>().online.value
            : true;
        final optimistic = ChatMessage.voice(
          id: clientId,
          dir: ChatDir.outgoing,
          time: formatMessageClock(DateTime.now()),
          createdAt: DateTime.now(),
          duration: WaveformUtils.formatDuration(recorded.duration),
          durationMs: recorded.duration.inMilliseconds,
          path: recorded.path,
          samples: recorded.samples,
          status: ChatStatus.pending,
          reply: replyUi,
          transcriptPending: true,
        );
        state.messages.add(optimistic);

        if (!online) {
          await OfflineChatStore.tryEnqueueOutbox({
            'kind': 'voice',
            'chat_id': state.chatId.value,
            'client_message_id': clientId,
            'file_path': recorded.path,
            'duration_ms': recorded.duration.inMilliseconds,
            'samples': WaveformUtils.resampleBars(recorded.samples, 40),
            'reply_to_id': replyToId,
            'created_at': DateTime.now().toIso8601String(),
          });
          _bumpConversationPreview('chat_preview_voice'.tr);
          _sendTyping(state, isTyping: false);
          state.sending.value = false;
          return;
        }
        _bumpConversationPreview('chat_preview_voice'.tr);

        final upload = await Get.find<ChatRepository>().uploadMedia(
          filePath: recorded.path,
          mediaType: 'voice',
        );
        final uploadMap = asMap(upload.dataOrNull);
        final mediaId = (uploadMap?['id'] as num?)?.toInt();
        if (mediaId == null) {
          final err = upload.errorOrNull;
          if (isNetworkFailure(err)) {
            final idx = state.messages.indexWhere((m) => m.id == clientId);
            if (idx >= 0) {
              state.messages[idx] =
                  state.messages[idx].withStatus(ChatStatus.pending);
            }
            await OfflineChatStore.tryEnqueueOutbox({
              'kind': 'voice',
              'chat_id': state.chatId.value,
              'client_message_id': clientId,
              'file_path': recorded.path,
              'duration_ms': recorded.duration.inMilliseconds,
              'samples': WaveformUtils.resampleBars(recorded.samples, 40),
              'reply_to_id': replyToId,
              'created_at': DateTime.now().toIso8601String(),
            });
            _scheduleOutboxFlush();
          } else {
            state.messages.removeWhere((m) => m.id == optimistic.id);
            if (err != null) {
              showAppError(err);
            } else {
              showAppMessage('voice_upload_failed'.tr);
            }
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
        await send.when(
          success: (data) async {
            final map = asMap(data);
            if (map == null) {
              final idx = state.messages.indexWhere((m) => m.id == clientId);
              if (idx >= 0) {
                state.messages[idx] =
                    state.messages[idx].withStatus(ChatStatus.pending);
              }
              await OfflineChatStore.tryEnqueueOutbox({
                'kind': 'voice',
                'chat_id': state.chatId.value,
                'client_message_id': clientId,
                'file_path': recorded.path,
                'duration_ms': recorded.duration.inMilliseconds,
                'samples': downsampled,
                'reply_to_id': replyToId,
                'created_at': DateTime.now().toIso8601String(),
              });
              _scheduleOutboxFlush();
              return;
            }
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
              status: real.status == ChatStatus.pending
                  ? ChatStatus.sent
                  : real.status,
              reply: real.reply ?? replyUi,
              senderId: real.senderId,
              senderName: real.senderName,
              senderAvatarUrl: real.senderAvatarUrl,
              text: real.text,
              textOriginal: real.textOriginal,
              showingOriginal: real.showingOriginal,
              transcriptPending: real.transcriptPending,
              transcriptFailed: real.transcriptFailed,
            );
            final idx = state.messages.indexWhere((m) => m.id == clientId || m.id == real.id);
            if (idx >= 0) state.messages[idx] = merged;
            await OfflineChatStore.removeOutbox(clientId);
          },
          failure: (err) async {
            if (isNetworkFailure(err)) {
              final idx = state.messages.indexWhere((m) => m.id == clientId);
              if (idx >= 0) {
                state.messages[idx] =
                    state.messages[idx].withStatus(ChatStatus.pending);
              }
              await OfflineChatStore.tryEnqueueOutbox({
                'kind': 'voice',
                'chat_id': state.chatId.value,
                'client_message_id': clientId,
                'file_path': recorded.path,
                'duration_ms': recorded.duration.inMilliseconds,
                'samples': downsampled,
                'reply_to_id': replyToId,
                'created_at': DateTime.now().toIso8601String(),
              });
              _scheduleOutboxFlush();
            } else {
              state.messages.removeWhere((m) => m.id == clientId);
              showAppError(err);
            }
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
          state.searchMatchIds.clear();
          state.searchMatchIndex.value = 0;
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
    final backChatId =
        state.isGroup.value ? null : state.chatId.value;
    await _openUserProfile(
      state.peerId.value,
      preview: UserProfilePayload.preview(
        id: state.peerId.value,
        name: state.peerName.value,
        initial: state.peerInitial.value,
        avatarGradient: state.peerAvatar.value,
        avatarUrl: state.peerAvatarUrl.value,
        existingChatId: backChatId,
      ),
    );
  }

  bool _openingProfile = false;

  Future<void> _openUserProfile(
    int userId, {
    UserProfilePayload? preview,
    String? previewName,
  }) async {
    if (userId <= 0) {
      showAppWarning('chat_profile_unavailable'.tr);
      return;
    }
    if (_openingProfile) return;
    _openingProfile = true;
    try {
      final backChatId = !state.isGroup.value &&
              userId == state.peerId.value &&
              state.chatId.value > 0
          ? state.chatId.value
          : preview?.existingChatId;
      final payload = preview ??
          UserProfilePayload.preview(
            id: userId,
            name: previewName ??
                (userId == state.peerId.value
                    ? state.peerName.value
                    : 'User'),
            initial: userId == state.peerId.value
                ? state.peerInitial.value
                : null,
            avatarGradient: userId == state.peerId.value
                ? state.peerAvatar.value
                : null,
            avatarUrl: userId == state.peerId.value
                ? state.peerAvatarUrl.value
                : null,
            existingChatId: backChatId,
          );
      await navigate(UserProfileScreen(), payload: payload);
    } finally {
      _openingProfile = false;
    }
  }

  bool _isGroupAdmin() =>
      state.myRole == 'owner' || state.myRole == 'admin';

  /// Telegram: DM da hammaga; guruhda o'z xabari yoki admin.
  bool _canDeleteMessageForEveryone(ChatMessage msg) {
    if (!state.isGroup.value) return true;
    if (msg.isOutgoing) return true;
    return _isGroupAdmin();
  }

  Future<void> _markReadSafe(int chatId, List<int> ids) async {
    final result = await Get.find<ChatRepository>().markRead(chatId, ids);
    result.when(
      success: (_) {},
      failure: (err) => debugPrint('markRead failed chat=$chatId: $err'),
    );
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
    final snapshot = state.messages.toList();
    final pinnedSnapshot = state.pinnedMessages.toList();
    final bannerSnapshot = state.pinnedBanner.value;
    final replySnapshot = state.replyTo.value;
    state.messages.clear();
    state.replyTo.value = null;
    state.pinnedBanner.value = null;
    state.pinnedMessages.clear();
    if (state.chatId.value > 0) {
      final result = await Get.find<ChatRepository>().clearHistory(
        state.chatId.value,
        forEveryone: forEveryone,
      );
      var ok = false;
      result.when(
        success: (_) {
          ok = true;
        },
        failure: showAppError,
      );
      if (!ok) {
        state.messages.assignAll(snapshot);
        state.pinnedMessages.assignAll(pinnedSnapshot);
        state.pinnedBanner.value = bannerSnapshot;
        state.replyTo.value = replySnapshot;
        return;
      }
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
    final online = Get.isRegistered<ConnectivityService>()
        ? Get.find<ConnectivityService>().online.value
        : true;
    final optimistic = ChatMessage.text(
      id: clientId,
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      text: text,
      status: ChatStatus.pending,
      reply: replyUi,
    );
    state.messages.add(optimistic);
    state.input.value = '';
    state.replyTo.value = null;
    _sendTyping(state, isTyping: false);
    _bumpConversationPreview(text);

    if (!online) {
      await OfflineChatStore.tryEnqueueOutbox({
        'kind': 'text',
        'chat_id': state.chatId.value,
        'client_message_id': clientId,
        'text': text,
        'reply_to_id': replyToId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return;
    }

    final result = await Get.find<ChatRepository>().sendText(
      chatId: state.chatId.value,
      text: text,
      clientMessageId: clientId,
      replyToId: replyToId,
    );
    await result.when(
      success: (data) async {
        final map = asMap(data);
        if (map == null) {
          await _markPendingKeep(state, clientId, text, replyToId);
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
        await OfflineChatStore.removeOutbox(clientId);
      },
      failure: (err) async {
        if (isNetworkFailure(err)) {
          await _markPendingKeep(state, clientId, text, replyToId);
          return;
        }
        state.messages.removeWhere(
          (m) => m.id == clientId || m.id == optimistic.id,
        );
        state.input.value = text;
        showAppError(err);
      },
    );
  }

  Future<void> _markPendingKeep(
    ChatState state,
    String clientId,
    String text,
    int? replyToId,
  ) async {
    final idx = state.messages.indexWhere((m) => m.id == clientId);
    if (idx >= 0) {
      state.messages[idx] = state.messages[idx].withStatus(ChatStatus.pending);
    }
    await OfflineChatStore.tryEnqueueOutbox({
      'kind': 'text',
      'chat_id': state.chatId.value,
      'client_message_id': clientId,
      'text': text,
      'reply_to_id': replyToId,
      'created_at': DateTime.now().toIso8601String(),
    });
    _scheduleOutboxFlush();
  }

  void _scheduleOutboxFlush() {
    if (!Get.isRegistered<OfflineOutboxService>()) return;
    unawaited(Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (Get.isRegistered<ConnectivityService>()) {
        final ok = await Get.find<ConnectivityService>().refresh();
        if (!ok) return;
      }
      await Get.find<OfflineOutboxService>().flush();
    }));
  }

  void _bumpConversationPreview(String preview) {
    if (!Get.isRegistered<MessagesState>()) return;
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    final messages = Get.find<MessagesState>();
    final list = messages.conversations.toList();
    final i = list.indexWhere((c) => c.id == chatId);
    if (i < 0) return;
    final old = list[i];
    list.removeAt(i);
    list.insert(
      0,
      old.copyWith(
        lastMessage: preview,
        time: formatChatTime(DateTime.now()),
      ),
    );
    messages.conversations.assignAll(list);
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
          final pinned = msg.withPinned(true);
          state.pinnedMessages.removeWhere((m) => m.id == msg.id);
          state.pinnedMessages.add(pinned);
          state.pinnedBanner.value = pinned;
        } else {
          state.pinnedMessages.removeWhere((m) => m.id == msg.id);
          state.pinnedBanner.value = state.pinnedMessages.isNotEmpty
              ? state.pinnedMessages.last
              : null;
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

  Future<void> _attachVideo({required bool roundNote}) async {
    final file = await pickChatVideo(
      context,
      maxSeconds: roundNote ? 60 : 120,
      roundNote: roundNote,
    );
    if (file == null) return;
    final optimistic = ChatMessage.video(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      url: file.path,
      isRoundNote: roundNote,
      status: ChatStatus.sent,
      reply: _replyFor(state),
      transcriptPending: true,
    );
    await _uploadAndSendMedia(
      filePath: file.path,
      mediaType: 'video',
      messageType: 'video',
      optimistic: optimistic,
      extraMeta: {
        if (roundNote) 'is_round_note': true,
      },
    );
  }

  Future<void> _attachFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      showAppMessage('file_open_failed'.tr);
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
    final contact = await showShareContactBottomSheet(context);
    if (contact == null) return;
    final name = contact.name.trim();
    if (name.isEmpty) return;
    final phone = contact.phone.trim();
    final number = contact.number?.trim();
    final optimistic = ChatMessage.contact(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      name: name,
      phone: phone,
      initial: initialsOf(name),
      status: ChatStatus.sent,
      userId: contact.userId,
      avatarUrl: contact.avatarUrl,
      number: number,
    );
    await _sendMetaMessage(
      type: 'contact',
      meta: {
        'contact_name': name,
        if (phone.isNotEmpty) 'contact_phone': phone,
        if (contact.userId != null) 'contact_user_id': contact.userId,
        if ((contact.avatarUrl ?? '').isNotEmpty)
          'contact_avatar_url': contact.avatarUrl,
        if ((number ?? '').isNotEmpty) 'contact_number': number,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _suggestAiReply(ChatMessage? focus, {String tone = 'professional'}) async {
    if (state.chatId.value <= 0 || state.aiSuggesting.value) return;
    state.aiSuggesting.value = true;
    state.aiSuggestTone.value = tone;
    state.aiSuggestMessageId.value = focus?.id;
    int? messageId;
    if (focus != null && !focus.isOutgoing) {
      messageId = int.tryParse(focus.id);
    } else {
      for (final m in state.messages.reversed) {
        if (!m.isOutgoing &&
            (m.type == ChatMsgType.text ||
                m.type == ChatMsgType.voice ||
                m.type == ChatMsgType.video) &&
            m.displayText.trim().isNotEmpty) {
          messageId = int.tryParse(m.id);
          break;
        }
      }
    }
    final result = await Get.find<ChatRepository>().suggestReply(
      state.chatId.value,
      messageId: messageId,
      tone: tone,
    );
    result.when(
      success: (data) {
        final map = asMap(data);
        final text = map?['text']?.toString().trim() ?? '';
        if (text.isEmpty) {
          showAppMessage('chat_ai_empty'.tr);
          return;
        }
        state.input.value = text;
        if (focus != null && !focus.isOutgoing) {
          state.replyTo.value = focus;
        }
        _toast('chat_ai_ready'.tr);
      },
      failure: showAppError,
    );
    state.aiSuggesting.value = false;
    state.aiSuggestTone.value = null;
    state.aiSuggestMessageId.value = null;
  }

  Future<void> _showAiSummary() async {
    if (state.chatId.value <= 0) return;
    if (!context.mounted) return;
    await showChatSummaryBottomSheet(
      context,
      load: () async {
        final result =
            await Get.find<ChatRepository>().chatSummary(state.chatId.value);
        final err = result.errorOrNull;
        if (err != null) {
          throw err.toString();
        }
        final map = asMap(result.dataOrNull);
        if (map == null) return null;
        return ChatSummaryData.fromApi(map);
      },
    );
  }

  Future<void> _attachInvoice() async {
    if (!context.mounted) return;
    final draft = await showInvoiceComposeBottomSheet(context);
    if (draft == null) return;
    final amountLabel = '${draft.amount} ${draft.currency}'.trim();
    final optimistic = ChatMessage.invoice(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      title: draft.title,
      amount: amountLabel,
      note: draft.note.isEmpty ? null : draft.note,
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'invoice',
      meta: {
        'title': draft.title,
        'amount': draft.amount,
        'currency': draft.currency,
        if (draft.note.isNotEmpty) 'note': draft.note,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _attachOffer({OfferDraft? initial}) async {
    if (!context.mounted) return;
    final draft = await showOfferComposeBottomSheet(
      context,
      initial: initial,
    );
    if (draft == null) return;
    await _sendOfferDraft(draft);
  }

  Future<void> _attachRfq() async {
    if (!context.mounted) return;
    final draft = await showRfqComposeBottomSheet(context);
    if (draft == null) return;
    await _sendRfqDraft(draft);
  }

  Future<void> _sendRfqDraft(RfqDraft draft) async {
    final unitLabel = 'chat_rfq_unit_${draft.unit}'.tr;
    final optimistic = ChatMessage.rfq(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      product: draft.product,
      quantity: draft.quantity,
      unit: unitLabel,
      specs: draft.specs.isEmpty ? null : draft.specs,
      deadline: draft.deadline.isEmpty ? null : draft.deadline,
      chatStatus: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'rfq',
      meta: {
        'product': draft.product,
        'quantity': draft.quantity,
        'unit': draft.unit,
        if (draft.specs.isNotEmpty) 'specs': draft.specs,
        if (draft.deadline.isNotEmpty) 'deadline': draft.deadline,
      },
      text:
          '${draft.product} · ${draft.quantity} $unitLabel'.trim(),
      optimistic: optimistic,
    );
  }

  Future<void> _replyToRfq(ChatMessage msg) async {
    if (msg.type != ChatMsgType.rfq) return;
    if (!context.mounted) return;
    state.replyTo.value = msg;
    final qty = [
      msg.rfqQuantity ?? '',
      msg.rfqUnit ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final draft = await showOfferComposeBottomSheet(
      context,
      initial: OfferDraft(
        product: msg.rfqProduct ?? '',
        price: '',
        currency: 'USD',
        delivery: '',
        moq: qty,
        payment: '',
      ),
    );
    if (draft == null) {
      state.replyTo.value = null;
      return;
    }
    await _sendOfferDraft(draft);
  }

  Future<void> _sendOfferDraft(OfferDraft draft) async {
    final optimistic = ChatMessage.offer(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      product: draft.product,
      price: draft.price,
      currency: draft.currency,
      delivery: draft.delivery.isEmpty ? null : draft.delivery,
      moq: draft.moq.isEmpty ? null : draft.moq,
      payment: draft.payment.isEmpty ? null : draft.payment,
      status: draft.status,
      productId: draft.productId,
      chatStatus: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'offer',
      meta: {
        'product': draft.product,
        'price': draft.price,
        'currency': draft.currency,
        'status': draft.status,
        if (draft.delivery.isNotEmpty) 'delivery': draft.delivery,
        if (draft.moq.isNotEmpty) 'moq': draft.moq,
        if (draft.payment.isNotEmpty) 'payment': draft.payment,
        if (draft.productId != null) 'product_id': draft.productId,
      },
      text: '${draft.product} · ${draft.price} ${draft.currency}'.trim(),
      optimistic: optimistic,
    );
  }

  Future<void> _acceptOffer(ChatMessage msg) async {
    if (msg.type != ChatMsgType.offer) return;
    final draft = OfferDraft(
      product: msg.offerProduct ?? '',
      price: msg.offerPrice ?? '',
      currency: msg.offerCurrency ?? 'USD',
      delivery: msg.offerDelivery ?? '',
      moq: msg.offerMoq ?? '',
      payment: msg.offerPayment ?? '',
      productId: msg.productId,
      status: 'accepted',
    );
    if (draft.product.isEmpty || draft.price.isEmpty) return;
    await _sendOfferDraft(draft);
    _toast('chat_offer_accepted_toast'.tr);
  }

  Future<void> _counterOffer(ChatMessage msg) async {
    if (msg.type != ChatMsgType.offer) return;
    await _attachOffer(
      initial: OfferDraft(
        product: msg.offerProduct ?? '',
        price: msg.offerPrice ?? '',
        currency: msg.offerCurrency ?? 'USD',
        delivery: msg.offerDelivery ?? '',
        moq: msg.offerMoq ?? '',
        payment: msg.offerPayment ?? '',
        productId: msg.productId,
        status: 'countered',
      ),
    );
  }

  Future<void> _attachCatalog() async {
    final result = await Get.find<ProductsRepository>().listMine(limit: 20);
    final items = asList(result.dataOrNull)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .toList();
    if (items.isEmpty) {
      if (result.errorOrNull != null) {
        showAppError(result.errorOrNull!);
      } else {
        showAppMessage('chat_catalog_empty'.tr);
      }
      return;
    }
    final me = SessionStore.user() ?? {};
    final biz = me['business'];
    final company = biz is Map
        ? (biz['company_name']?.toString() ?? '')
        : '';
    final title = company.isNotEmpty
        ? company
        : (me['full_name']?.toString() ?? 'chat_catalog_label'.tr);
    final names = items.map((e) => e.name).where((e) => e.isNotEmpty).toList();
    final preview = names.take(4).join(' · ');
    final optimistic = ChatMessage.catalog(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      title: title,
      subtitle: 'chat_catalog_count'.trParams({'n': '${items.length}'}),
      detail: preview,
      imageUrl: items.first.imageUrl,
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'catalog',
      meta: {
        'title': title,
        'count': items.length,
        'subtitle': 'chat_catalog_count'.trParams({'n': '${items.length}'}),
        'preview': preview,
        'items': names.take(8).toList(),
        'product_ids': items.map((e) => e.id).toList(),
        if (items.first.imageUrl != null) 'image_url': items.first.imageUrl,
        if (company.isNotEmpty) 'company_name': company,
      },
      optimistic: optimistic,
    );
  }

  Future<void> _attachBusinessCard() async {
    final meResult = await Get.find<ProfileRepository>().getMe();
    final me = asMap(meResult.dataOrNull) ?? SessionStore.user() ?? {};
    final bizRaw = me['business'];
    final biz = bizRaw is Map ? Map<String, dynamic>.from(bizRaw) : null;
    final name = (biz?['company_name']?.toString().trim().isNotEmpty == true)
        ? biz!['company_name'].toString()
        : (me['full_name']?.toString() ?? 'AnyLang');
    final role = biz?['business_role']?.toString();
    final phone = me['phone']?.toString() ?? '';
    final website = biz?['website']?.toString();
    final avatar = biz?['logo_url']?.toString() ?? me['avatar_url']?.toString();
    final userId = (me['id'] as num?)?.toInt() ?? SessionStore.userId();
    final detailParts = <String>[
      if ((role ?? '').isNotEmpty) 'business_role_$role'.tr,
      if (phone.isNotEmpty) phone,
      if ((website ?? '').isNotEmpty) website!,
    ];
    final optimistic = ChatMessage.businessCard(
      id: _nextId(),
      dir: ChatDir.outgoing,
      time: formatMessageClock(DateTime.now()),
      createdAt: DateTime.now(),
      name: name,
      company: biz?['company_name']?.toString(),
      role: role,
      phone: phone,
      imageUrl: avatar,
      userId: userId,
      status: ChatStatus.sent,
    );
    await _sendMetaMessage(
      type: 'business_card',
      meta: {
        'name': name,
        'user_id': userId,
        if (biz?['company_name'] != null)
          'company_name': biz!['company_name'],
        if ((role ?? '').isNotEmpty) 'business_role': role,
        if (phone.isNotEmpty) 'phone': phone,
        if ((website ?? '').isNotEmpty) 'website': website,
        if ((avatar ?? '').isNotEmpty) 'avatar_url': avatar,
        if (detailParts.isNotEmpty) 'preview': detailParts.join(' · '),
      },
      optimistic: optimistic,
    );
  }

  Future<void> _openSharedContactChat(ChatMessage msg) async {
    final userId = msg.contactUserId;
    if (userId != null && userId > 0) {
      if (userId == SessionStore.userId()) {
        showAppMessage('chat_contact_self'.tr);
        return;
      }
      final chat = await Get.find<ChatRepository>().createChat(userId);
      final map = asMap(chat.dataOrNull);
      if (map == null) {
        if (chat.errorOrNull != null) showAppError(chat.errorOrNull);
        return;
      }
      final chatId = (map['id'] as num?)?.toInt() ?? 0;
      if (chatId <= 0) return;
      final name = msg.contactName ?? 'User';
      await navigate(
        ChatScreen(),
        payload: ChatPayload(
          chatId: chatId,
          peerId: userId,
          name: name,
          initial: initialsOf(name),
          avatarGradient: avatarGradientFor(userId),
          avatarUrl: msg.contactAvatarUrl,
        ),
      );
      return;
    }
    final phone = (msg.contactPhone ?? '').trim();
    if (phone.isEmpty) {
      showAppMessage('chat_contact_no_phone'.tr);
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _addSharedContact(ChatMessage msg) async {
    final userId = msg.contactUserId;
    if (userId != null && userId > 0) {
      if (userId == SessionStore.userId()) {
        showAppMessage('chat_contact_self'.tr);
        return;
      }
      final result = await Get.find<FriendsRepository>().sendRequest(userId);
      result.when(
        success: (_) => showAppMessage('chat_contact_added'.tr),
        failure: showAppError,
      );
      return;
    }
    final phone = (msg.contactPhone ?? '').trim();
    if (phone.isEmpty) {
      showAppMessage('chat_contact_no_phone'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    showAppMessage('chat_contact_phone_copied'.tr);
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
    final online = Get.isRegistered<ConnectivityService>()
        ? Get.find<ConnectivityService>().online.value
        : true;
    final status = ChatStatus.pending;
    // Optimistic id = clientId — WS echo bilan merge ishlasin.
    final optimisticRow = switch (optimistic.type) {
      ChatMsgType.image => ChatMessage.image(
          id: clientId,
          dir: optimistic.dir,
          time: optimistic.time,
          createdAt: optimistic.createdAt,
          url: optimistic.imageUrl,
          gradient: avatarTealGradient,
          status: status,
          reply: replyUi,
        ),
      ChatMsgType.video => ChatMessage.video(
          id: clientId,
          dir: optimistic.dir,
          time: optimistic.time,
          createdAt: optimistic.createdAt,
          url: optimistic.videoUrl,
          isRoundNote: optimistic.isRoundNote,
          duration: optimistic.videoDuration,
          durationMs: optimistic.videoDurationMs,
          status: status,
          reply: replyUi,
          transcriptPending: optimistic.transcriptPending,
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
          status: status,
        ),
      _ => optimistic.withStatus(status),
    };
    state.messages.add(optimisticRow);

    if (!online) {
      await OfflineChatStore.tryEnqueueOutbox({
        'kind': messageType,
        'chat_id': state.chatId.value,
        'client_message_id': clientId,
        'file_path': filePath,
        'media_type': mediaType,
        'file_name': optimistic.fileName,
        'file_size': optimistic.fileSize,
        'file_ext': optimistic.fileExt,
        'reply_to_id': replyToId,
        'extra_meta': extraMeta,
        'created_at': DateTime.now().toIso8601String(),
      });
      _bumpConversationPreview(switch (messageType) {
        'image' => 'chat_preview_photo'.tr,
        'video' => 'chat_preview_video'.tr,
        'voice' => 'chat_preview_voice'.tr,
        _ => 'chat_preview_file'.tr,
      });
      _sendTyping(state, isTyping: false);
      state.sending.value = false;
      return;
    }
    _bumpConversationPreview(switch (messageType) {
      'image' => 'chat_preview_photo'.tr,
      'video' => 'chat_preview_video'.tr,
      'voice' => 'chat_preview_voice'.tr,
      _ => 'chat_preview_file'.tr,
    });

    final repo = Get.find<ChatRepository>();
    final upload = await repo.uploadMedia(
      filePath: filePath,
      mediaType: mediaType,
    );
    final uploadMap = asMap(upload.dataOrNull);
    final mediaId = (uploadMap?['id'] as num?)?.toInt();
    if (mediaId == null) {
      final err = upload.errorOrNull;
      if (isNetworkFailure(err)) {
        final idx = state.messages.indexWhere((m) => m.id == clientId);
        if (idx >= 0) {
          state.messages[idx] =
              state.messages[idx].withStatus(ChatStatus.pending);
        }
        await OfflineChatStore.tryEnqueueOutbox({
          'kind': messageType,
          'chat_id': state.chatId.value,
          'client_message_id': clientId,
          'file_path': filePath,
          'media_type': mediaType,
          'file_name': optimistic.fileName,
          'file_size': optimistic.fileSize,
          'file_ext': optimistic.fileExt,
          'reply_to_id': replyToId,
          'extra_meta': extraMeta,
          'created_at': DateTime.now().toIso8601String(),
        });
        _scheduleOutboxFlush();
      } else {
        state.messages.removeWhere((m) => m.id == optimisticRow.id);
        if (err != null) {
          showAppError(err);
        } else {
          showAppMessage('Fayl yuklanmadi');
        }
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
    await send.when(
      success: (data) async {
        final map = asMap(data);
        if (map == null) {
          final idx = state.messages.indexWhere((m) => m.id == clientId);
          if (idx >= 0) {
            state.messages[idx] =
                state.messages[idx].withStatus(ChatStatus.pending);
          }
          await OfflineChatStore.tryEnqueueOutbox({
            'kind': messageType,
            'chat_id': state.chatId.value,
            'client_message_id': clientId,
            'file_path': filePath,
            'media_type': mediaType,
            'file_name': optimistic.fileName,
            'file_size': optimistic.fileSize,
            'file_ext': optimistic.fileExt,
            'reply_to_id': replyToId,
            'extra_meta': extraMeta,
            'created_at': DateTime.now().toIso8601String(),
          });
          _scheduleOutboxFlush();
          return;
        }
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
        await OfflineChatStore.removeOutbox(clientId);
      },
      failure: (err) async {
        if (isNetworkFailure(err)) {
          final idx = state.messages.indexWhere((m) => m.id == clientId);
          if (idx >= 0) {
            state.messages[idx] =
                state.messages[idx].withStatus(ChatStatus.pending);
          }
          await OfflineChatStore.tryEnqueueOutbox({
            'kind': messageType,
            'chat_id': state.chatId.value,
            'client_message_id': clientId,
            'file_path': filePath,
            'media_type': mediaType,
            'file_name': optimistic.fileName,
            'file_size': optimistic.fileSize,
            'file_ext': optimistic.fileExt,
            'reply_to_id': replyToId,
            'extra_meta': extraMeta,
            'created_at': DateTime.now().toIso8601String(),
          });
          _scheduleOutboxFlush();
          return;
        }
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
    String? text,
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
      text: text,
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
        showAppMessage('product_not_found'.tr);
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
      existingPeerId: state.peerId.value,
      existingPeerChatId: state.chatId.value,
      onReturnToExistingChat: () {
        // Allaqachon shu chatdamiz — faqat sheet yopiladi.
      },
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
              payload: UserProfilePayload.fromApi(
                profileMap,
                existingChatId: product.sellerId == state.peerId.value
                    ? state.chatId.value
                    : null,
              ),
            );
          },
          failure: showAppError,
        );
      },
    );
  }

  void _recomputeSearchMatches(ChatState state) {
    final q = state.searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      state.searchMatchIds.clear();
      state.searchMatchIndex.value = 0;
      return;
    }
    final ids = <String>[];
    for (final m in state.messages) {
      if (_messageMatchesSearch(m, q)) {
        ids.add(m.id);
      }
    }
    state.searchMatchIds.assignAll(ids);
    if (ids.isEmpty) {
      state.searchMatchIndex.value = 0;
      return;
    }
    // Eng yangi topilmadan boshlash (Telegram uslubi).
    state.searchMatchIndex.value = ids.length - 1;
  }

  bool _messageMatchesSearch(ChatMessage m, String qLower) {
    final parts = <String>[
      m.displayText,
      m.previewText(),
      m.textOriginal ?? '',
      m.text ?? '',
      m.fileName ?? '',
      m.cardTitle ?? '',
      m.cardSubtitle ?? '',
      m.productTitle ?? '',
      m.locationLabel ?? '',
      m.contactName ?? '',
    ];
    for (final p in parts) {
      if (p.toLowerCase().contains(qLower)) return true;
    }
    return false;
  }

  void _moveSearchMatch(ChatState state, int delta) {
    final ids = state.searchMatchIds;
    if (ids.isEmpty) return;
    final next = (state.searchMatchIndex.value + delta).clamp(0, ids.length - 1);
    state.searchMatchIndex.value = next;
  }

  void _toast(String msg) => showAppMessage(msg);
}
