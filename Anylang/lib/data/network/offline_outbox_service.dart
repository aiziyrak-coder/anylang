import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../audio/waveform_utils.dart';
import '../core/mappers.dart';
import '../local/offline_chat_store.dart';
import '../local/session_store.dart';
import '../../presentation/screens/chat/chat_message.dart';
import '../../presentation/screens/chat/chat_state.dart';
import '../../presentation/screens/messages/messages_state.dart';
import 'chat_repository.dart';
import 'connectivity_service.dart';
import 'realtime_sync_service.dart';
import '../../presentation/utils/app_snackbar.dart';

/// Offline outbox — ulanish tiklanganda yuborilmagan xabarlarni flush qiladi.
class OfflineOutboxService extends GetxService {
  StreamSubscription<bool>? _sub;
  bool _flushing = false;
  bool _queued = false;

  Future<OfflineOutboxService> init() async {
    await OfflineChatStore.open();
    if (Get.isRegistered<ConnectivityService>()) {
      final c = Get.find<ConnectivityService>();
      _sub = c.onStatus.listen((online) {
        if (online) unawaited(flush());
      });
      if (c.online.value && OfflineChatStore.hasOutbox) {
        unawaited(flush());
      }
    }
    return this;
  }

  Future<void> flush() async {
    if (_flushing) {
      _queued = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _queued = false;
        await _flushOnce();
      } while (_queued);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushOnce() async {
    final online = Get.isRegistered<ConnectivityService>()
        ? await Get.find<ConnectivityService>().refresh()
        : await ConnectivityService.probe();
    if (!online) return;
    if (!Get.isRegistered<ChatRepository>()) return;
    if (!OfflineChatStore.hasOutbox) return;

    final items =
        List<Map<String, dynamic>>.from(OfflineChatStore.loadOutbox());
    final repo = Get.find<ChatRepository>();
    for (final item in items) {
      final clientId = item['client_message_id']?.toString();
      final chatId = (item['chat_id'] as num?)?.toInt() ?? 0;
      if (clientId == null || clientId.isEmpty || chatId <= 0) {
        if (clientId != null && clientId.isNotEmpty) {
          await OfflineChatStore.removeOutbox(clientId);
        }
        continue;
      }

      final kind = item['kind']?.toString() ?? 'text';
      final replyToId = (item['reply_to_id'] as num?)?.toInt();
      Map<String, dynamic>? responseMap;
      var permanentFail = false;
      var networkFail = false;

      try {
        if (kind == 'text') {
          final text = item['text']?.toString() ?? '';
          if (text.trim().isEmpty) {
            permanentFail = true;
          } else {
            final r = await repo.sendText(
              chatId: chatId,
              text: text,
              clientMessageId: clientId,
              replyToId: replyToId,
            );
            if (r.errorOrNull == null) {
              responseMap = asMap(r.dataOrNull);
            } else if (isNetworkFailure(r.errorOrNull)) {
              networkFail = true;
            } else {
              permanentFail = true;
            }
          }
        } else if (kind == 'voice' ||
            kind == 'image' ||
            kind == 'file' ||
            kind == 'video') {
          final path = item['file_path']?.toString();
          if (path == null || path.isEmpty || !File(path).existsSync()) {
            permanentFail = true;
          } else {
            final mediaType = item['media_type']?.toString() ??
                (kind == 'voice' ? 'voice' : kind);
            final upload = await repo.uploadMedia(
              filePath: path,
              mediaType: mediaType,
            );
            final map = asMap(upload.dataOrNull);
            final mediaId = (map?['id'] as num?)?.toInt();
            if (mediaId == null) {
              if (isNetworkFailure(upload.errorOrNull)) {
                networkFail = true;
              } else {
                permanentFail = true;
              }
            } else {
              Map<String, dynamic>? meta;
              if (kind == 'voice') {
                meta = {
                  'duration_ms': item['duration_ms'],
                  'samples': item['samples'] ??
                      WaveformUtils.resampleBars(const [], 40),
                };
              } else if (item['extra_meta'] is Map) {
                meta = Map<String, dynamic>.from(item['extra_meta'] as Map);
              }
              final sendType = switch (kind) {
                'voice' => 'voice',
                'video' => 'video',
                _ => kind,
              };
              final send = kind == 'voice'
                  ? await repo.sendVoice(
                      chatId: chatId,
                      clientMessageId: clientId,
                      mediaId: mediaId,
                      meta: meta,
                      replyToId: replyToId,
                    )
                  : await repo.sendMessage(
                      chatId: chatId,
                      clientMessageId: clientId,
                      type: sendType,
                      mediaId: mediaId,
                      meta: meta,
                      replyToId: replyToId,
                    );
              if (send.errorOrNull == null) {
                responseMap = asMap(send.dataOrNull);
              } else if (isNetworkFailure(send.errorOrNull)) {
                networkFail = true;
              } else {
                permanentFail = true;
              }
            }
          }
        } else {
          permanentFail = true;
        }
      } catch (e) {
        if (isNetworkFailure(e)) {
          networkFail = true;
        } else {
          permanentFail = true;
        }
      }

      if (networkFail) break;
      if (permanentFail) {
        await OfflineChatStore.removeOutbox(clientId);
        _dropLocalPending(chatId, clientId);
        showAppError('outbox_send_failed'.tr);
        continue;
      }

      await OfflineChatStore.removeOutbox(clientId);
      _applySentToUi(
        chatId: chatId,
        clientId: clientId,
        responseMap: responseMap,
        kind: kind,
      );
    }
  }

  void _dropLocalPending(int chatId, String clientId) {
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    chat.messages.removeWhere((m) => m.id == clientId);
  }

  void _applySentToUi({
    required int chatId,
    required String clientId,
    required Map<String, dynamic>? responseMap,
    required String kind,
  }) {
    if (Get.isRegistered<ChatState>()) {
      final chat = Get.find<ChatState>();
      if (chat.chatId.value == chatId) {
        final idx = chat.messages.indexWhere((m) => m.id == clientId);
        if (responseMap != null) {
          final mapped = mapChatMessageFromApi(
            responseMap,
            me: SessionStore.userId(),
            peerName: chat.peerName.value,
          );
          ChatMessage next = mapped.status == ChatStatus.pending
              ? mapped.withStatus(ChatStatus.sent)
              : mapped;
          if (idx >= 0) {
            final prev = chat.messages[idx];
            if (prev.type == ChatMsgType.voice) {
              next = ChatMessage.voice(
                id: mapped.id,
                dir: mapped.dir,
                time: mapped.time,
                createdAt: mapped.createdAt,
                duration: prev.voiceDuration ?? mapped.voiceDuration ?? '0:00',
                durationMs: prev.voiceDurationMs ?? mapped.voiceDurationMs,
                path: (mapped.voicePath != null && mapped.voicePath!.isNotEmpty)
                    ? mapped.voicePath
                    : prev.voicePath,
                samples: prev.voiceSamples.isNotEmpty
                    ? prev.voiceSamples
                    : mapped.voiceSamples,
                downloaded: mapped.voiceDownloaded || prev.voiceDownloaded,
                status: mapped.status == ChatStatus.pending
                    ? ChatStatus.sent
                    : mapped.status,
                reply: mapped.reply ?? prev.reply,
                senderId: mapped.senderId,
                senderName: mapped.senderName,
                senderAvatarUrl: mapped.senderAvatarUrl,
                text: mapped.text,
                textOriginal: mapped.textOriginal,
                showingOriginal: prev.showingOriginal,
                transcriptPending: mapped.transcriptPending,
                transcriptFailed: mapped.transcriptFailed,
              );
            } else if (prev.type == ChatMsgType.image &&
                (mapped.imageUrl == null || mapped.imageUrl!.isEmpty) &&
                prev.imageUrl != null) {
              next = ChatMessage.image(
                id: mapped.id,
                dir: mapped.dir,
                time: mapped.time,
                createdAt: mapped.createdAt,
                url: prev.imageUrl,
                status: mapped.status == ChatStatus.pending
                    ? ChatStatus.sent
                    : mapped.status,
                reply: mapped.reply ?? prev.reply,
                senderId: mapped.senderId,
                senderName: mapped.senderName,
                senderAvatarUrl: mapped.senderAvatarUrl,
              );
            } else if (prev.type == ChatMsgType.file &&
                (mapped.fileUrl == null || mapped.fileUrl!.isEmpty) &&
                prev.fileUrl != null) {
              next = ChatMessage.file(
                id: mapped.id,
                dir: mapped.dir,
                time: mapped.time,
                createdAt: mapped.createdAt,
                name: mapped.fileName ?? prev.fileName ?? 'file',
                size: mapped.fileSize ?? prev.fileSize ?? '—',
                ext: mapped.fileExt ?? prev.fileExt ?? 'FILE',
                url: prev.fileUrl,
                status: mapped.status == ChatStatus.pending
                    ? ChatStatus.sent
                    : mapped.status,
                senderId: mapped.senderId,
                senderName: mapped.senderName,
                senderAvatarUrl: mapped.senderAvatarUrl,
              );
            }
            chat.messages[idx] = next;
          } else {
            chat.messages.add(next);
          }
        } else if (idx >= 0) {
          chat.messages[idx] = chat.messages[idx].withStatus(ChatStatus.sent);
        }
      }
    }

    if (Get.isRegistered<MessagesState>()) {
      final messages = Get.find<MessagesState>();
      final list = messages.conversations.toList();
      final i = list.indexWhere((c) => c.id == chatId);
      if (i >= 0) {
        final old = list[i];
        final preview = switch (kind) {
          'voice' => 'chat_preview_voice'.tr,
          'image' => 'chat_preview_photo'.tr,
          'video' => 'chat_preview_video'.tr,
          'file' => 'chat_preview_file'.tr,
          _ => (responseMap?['text']?.toString() ?? old.lastMessage),
        };
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
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
