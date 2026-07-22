import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/audio/voice_player_service.dart';
import '../../../data/audio/voice_recorder_service.dart';
import '../../../data/audio/waveform_utils.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/attachment_bottom_sheet.dart';
import '../../modal/chat_overflow_sheet.dart';
import '../../modal/message_actions_dialog.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
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

  @override
  void initState(ChatPayload? payload) {
    final p = payload;
    if (p == null) {
      popBackNavigate();
      return;
    }
    state.peerName = p.name;
    state.peerInitial = p.initial;
    state.peerAvatar = p.avatarGradient;
    state.peerOnline = p.online;
    state.chatId = p.chatId;
    state.peerId = p.peerId;
    state.muted.value = SessionStore.isChatMuted(p.chatId);
    state.searching.value = false;
    state.searchQuery.value = '';

    state.input.value = '';
    state.replyTo.value = null;
    state.recording.value = false;
    state.sending.value = false;
    state.messages.clear();
    state.loading.value = true;
    _loadMessages(p.chatId);
  }

  Future<void> _loadMessages(int chatId) async {
    final result = await Get.find<ChatRepository>().listMessages(chatId);
    result.when(
      success: (data) {
        final me = SessionStore.userId();
        final raw = asList(data)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final items = raw.map((e) => _fromApi(e, me)).toList();
        state.messages.assignAll(_fillMissingReplies(items, raw, me));
        final ids = items
            .where((m) => !m.isOutgoing)
            .map((m) => int.tryParse(m.id))
            .whereType<int>()
            .toList();
        if (ids.isNotEmpty) {
          Get.find<ChatRepository>().markRead(chatId, ids);
        }
      },
      failure: showAppError,
    );
    state.loading.value = false;
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
        author: parent.isOutgoing ? 'chat_you'.tr : state.peerName,
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
        duration: msg.voiceDuration ?? '0:00',
        durationMs: msg.voiceDurationMs,
        path: msg.voicePath,
        samples: msg.voiceSamples,
        downloaded: msg.voiceDownloaded,
        status: msg.status,
        reply: reply,
      );
    }
    return ChatMessage.text(
      id: msg.id,
      dir: msg.dir,
      time: msg.time,
      text: msg.text ?? '',
      status: msg.status,
      reply: reply,
    );
  }

  ChatStatus _statusFromApi(Map<String, dynamic> json, {required bool outgoing}) {
    if (!outgoing) return ChatStatus.read;
    if (json['read_by_recipient'] == true) return ChatStatus.read;
    final status = json['status']?.toString();
    if (status == 'read') return ChatStatus.read;
    if (status == 'delivered') return ChatStatus.delivered;
    return ChatStatus.sent;
  }

  ChatMessage _fromApi(
    Map<String, dynamic> json,
    int? me, {
    ChatReply? fallbackReply,
  }) {
    final senderId = (json['sender_id'] as num?)?.toInt();
    final outgoing = me != null && senderId == me;
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final text = (json['text'] as String?) ??
        (json['text_original'] as String?) ??
        '';
    final type = (json['type'] as String?) ?? 'text';
    final reply = _replyFromApi(json, me) ?? fallbackReply;
    final status = _statusFromApi(json, outgoing: outgoing);
    if (type == 'voice' || type == 'audio') {
      final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
      final durationMs = (meta['duration_ms'] as num?)?.toInt();
      final samples = (meta['samples'] as List?)
              ?.whereType<num>()
              .map((e) => e.toDouble())
              .toList() ??
          const <double>[];
      final url = meta['url']?.toString();
      return ChatMessage.voice(
        id: '${json['id']}',
        dir: outgoing ? ChatDir.outgoing : ChatDir.incoming,
        time: formatChatTime(created),
        duration: durationMs != null
            ? WaveformUtils.formatDuration(Duration(milliseconds: durationMs))
            : '0:00',
        durationMs: durationMs,
        path: url,
        samples: samples,
        downloaded: url != null && url.isNotEmpty,
        status: status,
        reply: reply,
      );
    }
    return ChatMessage.text(
      id: '${json['id']}',
      dir: outgoing ? ChatDir.outgoing : ChatDir.incoming,
      time: formatChatTime(created),
      text: text,
      status: status,
      reply: reply,
    );
  }

  ChatReply? _replyFromApi(Map<String, dynamic> json, int? me) {
    final nested = asMap(json['reply_to']);
    if (nested == null) return null;
    final senderId = (nested['sender_id'] as num?)?.toInt();
    final author = (me != null && senderId == me)
        ? 'chat_you'.tr
        : (nested['sender_name']?.toString().trim().isNotEmpty == true
            ? nested['sender_name'].toString()
            : state.peerName);
    final type = nested['type']?.toString() ?? 'text';
    final deleted = nested['is_deleted'] == true;
    final previewRaw = nested['preview_text']?.toString().trim();
    final previewText = deleted
        ? 'chat_reply_deleted'.tr
        : ((previewRaw != null && previewRaw.isNotEmpty)
            ? previewRaw
            : _previewForMsgType(type));
    final id = nested['id'];
    return ChatReply(
      author: author,
      preview: previewText,
      messageId: id == null ? null : '$id',
    );
  }

  String _previewForMsgType(String type) {
    return switch (type) {
      'image' => 'chat_preview_photo'.tr,
      'voice' || 'audio' => 'chat_preview_voice'.tr,
      'product' => 'chat_preview_product'.tr,
      'location' => 'chat_preview_location'.tr,
      'file' => 'chat_preview_file'.tr,
      'contact' => 'chat_preview_contact'.tr,
      _ => '',
    };
  }

  @override
  Future<void> actionHandler(ChatState state, MyAction action) async {
    switch (action) {
      case InputChanged a:
        state.input.value = a.text;

      case SendText _:
        final text = state.input.value.trim();
        if (text.isEmpty || state.chatId <= 0 || state.sending.value) return;
        state.sending.value = true;
        final clientId = 'c${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
        final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
        final replyUi = _replyFor(state);
        final optimistic = ChatMessage.text(
          id: _nextId(),
          dir: ChatDir.outgoing,
          time: _now(),
          text: text,
          status: ChatStatus.sent,
          reply: replyUi,
        );
        state.messages.add(optimistic);
        state.input.value = '';
        state.replyTo.value = null;

        final result = await Get.find<ChatRepository>().sendText(
          chatId: state.chatId,
          text: text,
          clientMessageId: clientId,
          replyToId: replyToId,
        );
        result.when(
          success: (data) {
            final map = asMap(data);
            if (map == null) return;
            final real = _fromApi(
              map,
              SessionStore.userId(),
              fallbackReply: replyUi,
            );
            final idx = state.messages.indexWhere((m) => m.id == optimistic.id);
            if (idx >= 0) state.messages[idx] = real;
          },
          failure: (err) {
            state.messages.removeWhere((m) => m.id == optimistic.id);
            state.input.value = text;
            showAppError(err);
          },
        );
        state.sending.value = false;

      case OpenAttachMenu _:
        final kind = await showAttachmentBottomSheet(context);
        if (kind != null) sendAction(PickAttachment(kind));

      case PickAttachment a:
        showAppMessage('Media yuklash tez orada');
        state.messages.add(_attachmentMessage(a.kind));

      case LongPressMessage a:
        final msg = a.message;
        final showTranslate =
            msg.type == ChatMsgType.text && !msg.isOutgoing;
        final chosen = await showMessageActionsDialog(
          context,
          message: msg,
          anchor: a.anchor,
          showTranslate: showTranslate,
        );
        switch (chosen) {
          case MessageMenuAction.reply:
            sendAction(StartReply(msg));
          case MessageMenuAction.copy:
            sendAction(CopyMessage(msg));
          case MessageMenuAction.delete:
            sendAction(DeleteMessage(msg));
          case MessageMenuAction.translate:
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
        final id = int.tryParse(a.message.id);
        state.messages.removeWhere((m) => m.id == a.message.id);
        if (state.replyTo.value?.id == a.message.id) {
          state.replyTo.value = null;
        }
        if (id != null) {
          await Get.find<ChatRepository>().deleteMessage(id);
        }

      case OpenChatMenu _:
        final chosen = await showChatOverflowSheet(
          context,
          muted: state.muted.value,
        );
        switch (chosen) {
          case ChatOverflowAction.profile:
            sendAction(OpenPeerProfile());
          case ChatOverflowAction.search:
            sendAction(ToggleChatSearch());
          case ChatOverflowAction.mute:
            sendAction(ToggleChatMute());
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
        await _openPeerProfile();

      case ToggleChatSearch _:
        final next = !state.searching.value;
        state.searching.value = next;
        if (!next) state.searchQuery.value = '';

      case ChatSearchChanged a:
        state.searchQuery.value = a.text;

      case ToggleChatMute _:
        final next = !state.muted.value;
        state.muted.value = next;
        await SessionStore.setChatMuted(state.chatId, next);
        _toast(next ? 'chat_muted'.tr : 'chat_unmuted'.tr);

      case ClearChatHistory _:
        final ok = await _confirm(
          title: 'chat_overflow_clear'.tr,
          body: 'chat_clear_confirm'.tr,
          confirmLabel: 'chat_overflow_clear'.tr,
        );
        if (ok) await _clearHistory(showToast: true);

      case DeleteChat _:
        final ok = await _confirm(
          title: 'chat_overflow_delete_chat'.tr,
          body: 'chat_delete_confirm'.tr,
          confirmLabel: 'chat_overflow_delete_chat'.tr,
          danger: true,
        );
        if (!ok) return;
        await _clearHistory(showToast: false);
        await Get.find<VoiceRecorderService>().cancel();
        await Get.find<VoicePlayerService>().stop(save: true);
        popBackNavigate();
        _toast('chat_deleted'.tr);

      case BlockPeer _:
        final ok = await _confirm(
          title: 'chat_overflow_block'.tr,
          body: 'chat_block_confirm'.tr,
          confirmLabel: 'chat_overflow_block'.tr,
          danger: true,
        );
        if (!ok) return;
        if (state.peerId > 0) {
          await SessionStore.setUserBlocked(state.peerId, true);
          await Get.find<FriendsRepository>().removeFriend(state.peerId);
        }
        await _clearHistory(showToast: false);
        await Get.find<VoiceRecorderService>().cancel();
        await Get.find<VoicePlayerService>().stop(save: true);
        popBackNavigate();
        _toast('chat_blocked'.tr);

      case StartRecording _:
        final player = Get.find<VoicePlayerService>();
        if (player.isPlaying.value) await player.stop(save: true);
        final ok = await Get.find<VoiceRecorderService>().start();
        if (!ok) {
          showAppMessage('Mikrofon uchun ruxsat berilmadi');
          return;
        }
        state.recording.value = true;

      case CancelRecording _:
        await Get.find<VoiceRecorderService>().cancel();
        state.recording.value = false;

      case SendVoice _:
        if (state.sending.value) return;
        final recorded = await Get.find<VoiceRecorderService>().stop();
        state.recording.value = false;
        if (recorded == null || state.chatId <= 0) return;

        state.sending.value = true;
        final clientId = 'v${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
        final replyToId = int.tryParse(state.replyTo.value?.id ?? '');
        final replyUi = _replyFor(state);
        state.replyTo.value = null;
        final optimistic = ChatMessage.voice(
          id: _nextId(),
          dir: ChatDir.outgoing,
          time: _now(),
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
            showAppMessage('Ovoz yuklanmadi');
          }
          state.sending.value = false;
          return;
        }

        final downsampled = WaveformUtils.resampleBars(recorded.samples, 40);
        final send = await Get.find<ChatRepository>().sendVoice(
          chatId: state.chatId,
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
              duration: optimistic.voiceDuration ?? real.voiceDuration ?? '0:00',
              durationMs: optimistic.voiceDurationMs ?? real.voiceDurationMs,
              path: optimistic.voicePath ?? real.voicePath,
              samples: optimistic.voiceSamples.isNotEmpty
                  ? optimistic.voiceSamples
                  : real.voiceSamples,
              status: real.status,
              reply: real.reply ?? replyUi,
            );
            final idx = state.messages.indexWhere((m) => m.id == optimistic.id);
            if (idx >= 0) state.messages[idx] = merged;
          },
          failure: (err) {
            state.messages.removeWhere((m) => m.id == optimistic.id);
            showAppError(err);
          },
        );
        state.sending.value = false;

      case Back _:
        if (state.searching.value) {
          state.searching.value = false;
          state.searchQuery.value = '';
          return;
        }
        await Get.find<VoiceRecorderService>().cancel();
        await Get.find<VoicePlayerService>().stop(save: true);
        popBackNavigate();
    }
  }

  Future<void> _openPeerProfile() async {
    if (state.peerId <= 0) {
      showAppWarning('chat_profile_unavailable'.tr);
      return;
    }
    final result =
        await Get.find<ProfileRepository>().getPublicUser(state.peerId);
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

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: danger ? const Color(0xFFB42318) : null,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _clearHistory({required bool showToast}) async {
    final ids = state.messages
        .map((m) => int.tryParse(m.id))
        .whereType<int>()
        .toList();
    state.messages.clear();
    state.replyTo.value = null;
    final repo = Get.find<ChatRepository>();
    await Future.wait(ids.map((id) => repo.deleteMessage(id)));
    if (showToast) _toast('chat_history_cleared'.tr);
  }

  String _nextId() => 'm${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  String _now() {
    final t = DateTime.now();
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  ChatReply? _replyFor(ChatState state) {
    final r = state.replyTo.value;
    if (r == null) return null;
    return ChatReply(
      author: r.isOutgoing ? 'chat_you'.tr : state.peerName,
      preview: r.previewText(),
      messageId: r.id,
    );
  }

  ChatMessage _attachmentMessage(AttachKind kind) {
    final id = _nextId();
    final time = _now();
    switch (kind) {
      case AttachKind.gallery:
      case AttachKind.camera:
        return ChatMessage.image(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          gradient: avatarTealGradient,
          status: ChatStatus.sent,
        );
      case AttachKind.product:
        return ChatMessage.product(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          title: 'chat_preview_product'.tr,
          price: '—',
          status: ChatStatus.sent,
        );
      case AttachKind.file:
        return ChatMessage.file(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          name: 'file.bin',
          size: '—',
          ext: 'BIN',
          status: ChatStatus.sent,
        );
      case AttachKind.location:
        return ChatMessage.location(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          label: 'Manzil',
          distance: '',
          status: ChatStatus.sent,
        );
      case AttachKind.contact:
        return ChatMessage.contact(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          name: 'Kontakt',
          phone: '',
          initial: 'K',
          status: ChatStatus.sent,
        );
    }
  }

  void _toast(String msg) => showAppMessage(msg);
}
