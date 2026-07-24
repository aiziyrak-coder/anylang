import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../audio/waveform_utils.dart';
import '../core/mappers.dart';
import '../local/session_store.dart';
import 'chat_repository.dart';
import 'socket_service.dart';
import '../../presentation/screens/chat/chat_message.dart';
import '../../presentation/screens/chat/chat_state.dart';
import '../../presentation/screens/friends/friends_state.dart';
import '../../presentation/screens/messages/conversation.dart';
import '../../presentation/screens/messages/messages_state.dart';
import '../../presentation/ui/theme/gradients.dart';

/// WebSocket eventlarini GetX state'larga ulaydi.
/// SocketService faqat stream beradi — tinglash shu yerda.
class RealtimeSyncService extends GetxService {
  StreamSubscription<Map<String, dynamic>>? _sub;
  int? _activeChatId;
  Timer? _typingClearTimer;

  int? get activeChatId => _activeChatId;

  void setActiveChat(int? chatId) => _activeChatId = chatId;

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  void _bind() {
    if (!Get.isRegistered<SocketService>()) return;
    _sub?.cancel();
    _sub = Get.find<SocketService>().messages.listen(
      _onEvent,
      onError: (e) => debugPrint('RealtimeSync error: $e'),
    );
  }

  /// Token yangilanganda yoki login'dan keyin qayta ulanish.
  void rebind() => _bind();

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final data = asMap(event['data']) ?? event;
    switch (type) {
      case 'new_message':
        _onNewMessage(data);
      case 'messages_read':
      case 'message_read':
        _onMessagesRead(data);
      case 'message_deleted':
        _onMessageDeleted(data);
      case 'message_edited':
        _onMessageEdited(data);
      case 'message_reaction':
        _onMessageReaction(data);
      case 'message_pinned':
      case 'message_unpinned':
        _onMessagePinEvent(data, pinned: type == 'message_pinned');
      case 'history_cleared':
        _onHistoryCleared(data);
      case 'group_deleted':
        _onGroupDeleted(data);
      case 'presence':
        _onPresence(data);
      case 'typing':
        _onTyping(data);
      default:
        break;
    }
  }

  void _onMessageEdited(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final msgMap = asMap(data['message']);
    if (chatId == null || msgMap == null) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    final mapped = mapChatMessageFromApi(msgMap, me: SessionStore.userId(), peerName: chat.peerName.value);
    final idx = chat.messages.indexWhere((m) => m.id == mapped.id);
    if (idx >= 0) chat.messages[idx] = mapped;
  }

  void _onMessageReaction(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final messageId = '${data['message_id']}';
    if (chatId == null) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    final reactions = (data['reactions'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final idx = chat.messages.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      chat.messages[idx] = chat.messages[idx].withReactions(reactions);
    }
  }

  void _onMessagePinEvent(Map<String, dynamic> data, {required bool pinned}) {
    final chatId = _asInt(data['chat_id']);
    final messageId = '${data['message_id']}';
    if (chatId == null) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    final idx = chat.messages.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      final msg = chat.messages[idx].withPinned(pinned);
      chat.messages[idx] = msg;
      chat.pinnedBanner.value = pinned ? msg : (chat.pinnedBanner.value?.id == messageId ? null : chat.pinnedBanner.value);
    }
  }

  void _onHistoryCleared(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    if (chatId == null) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    if (data['for_everyone'] == true) {
      chat.messages.clear();
      chat.pinnedBanner.value = null;
    }
  }

  void _onGroupDeleted(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    if (chatId == null) return;
    if (Get.isRegistered<MessagesState>()) {
      final messages = Get.find<MessagesState>();
      messages.conversations.removeWhere((c) => c.id == chatId);
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final msgMap = asMap(data['message']);
    if (chatId == null || msgMap == null) return;

    final me = SessionStore.userId();
    final senderId = _asInt(msgMap['sender_id']);
    final isMine = me != null && senderId == me;
    final msgId = '${msgMap['id']}';
    final clientId = msgMap['client_message_id']?.toString();

    // Open chat → append / merge
    if (Get.isRegistered<ChatState>()) {
      final chat = Get.find<ChatState>();
      if (chat.chatId.value == chatId) {
        final mapped = mapChatMessageFromApi(
          msgMap,
          me: me,
          peerName: chat.peerName.value,
        );
        final idx = chat.messages.indexWhere(
          (m) =>
              m.id == msgId ||
              (clientId != null &&
                  clientId.isNotEmpty &&
                  m.id == clientId),
        );
        if (idx >= 0) {
          chat.messages[idx] = mapped;
        } else {
          chat.messages.add(mapped);
        }
        if (!isMine) {
          chat.peerTyping.value = false;
          chat.peerActivity.value = '';
          final id = int.tryParse(msgId);
          if (id != null) {
            Get.find<ChatRepository>().markRead(chatId, [id]);
          }
        }
      }
    }

    // Conversations list preview
    if (!Get.isRegistered<MessagesState>()) return;
    final messages = Get.find<MessagesState>();
    final preview = _previewFromMessage(msgMap);
    final created = DateTime.tryParse(msgMap['created_at']?.toString() ?? '');
    final time = formatChatTime(created);

    final list = messages.conversations.toList();
    final i = list.indexWhere((c) => c.id == chatId);
    if (i >= 0) {
      final old = list[i];
      final filter = messages.listFilter.value;
      // Aktiv filterga mos kelmasa (masalan Guruhlarda DM) — olib tashla.
      if (filter == MessagesListFilter.groups && !old.isGroup) {
        list.removeAt(i);
        messages.conversations.assignAll(list);
        return;
      }
      if (filter == MessagesListFilter.chats && old.isGroup) {
        list.removeAt(i);
        messages.conversations.assignAll(list);
        return;
      }
      final bumpUnread = !isMine && _activeChatId != chatId;
      final unread = bumpUnread ? old.unread + 1 : (isMine ? old.unread : 0);
      // If viewing this chat, unread stays 0 / cleared
      final cleared = _activeChatId == chatId ? 0 : unread;
      list.removeAt(i);
      list.insert(
        0,
        old.copyWith(
          lastMessage: preview,
          time: time,
          unread: cleared,
          highlighted: cleared > 0,
        ),
      );
      messages.conversations.assignAll(list);
    } else if (!isMine) {
      // Unknown chat — soft refresh list in background
      unawaited(_softReloadConversations());
    }
  }

  void _onMessagesRead(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final ids = (data['message_ids'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};
    if (chatId == null || ids.isEmpty) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    for (var i = 0; i < chat.messages.length; i++) {
      final m = chat.messages[i];
      if (m.isOutgoing && ids.contains(m.id)) {
        chat.messages[i] = m.withStatus(ChatStatus.read);
      }
    }
  }

  void _onMessageDeleted(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final messageId = data['message_id']?.toString();
    if (chatId == null || messageId == null) return;
    if (Get.isRegistered<ChatState>()) {
      final chat = Get.find<ChatState>();
      if (chat.chatId.value == chatId) {
        chat.messages.removeWhere((m) => m.id == messageId);
      }
    }
    unawaited(_softReloadConversations());
  }

  void _onPresence(Map<String, dynamic> data) {
    final userId = _asInt(data['user_id']);
    final online = data['is_online'] == true;
    if (userId == null) return;

    if (Get.isRegistered<ChatState>()) {
      final chat = Get.find<ChatState>();
      if (chat.peerId.value == userId) {
        chat.peerOnline.value = online;
      }
    }

    if (Get.isRegistered<MessagesState>()) {
      final messages = Get.find<MessagesState>();
      final list = messages.conversations.toList();
      var changed = false;
      for (var i = 0; i < list.length; i++) {
        if (list[i].peerId == userId && list[i].online != online) {
          list[i] = list[i].copyWith(online: online);
          changed = true;
        }
      }
      if (changed) messages.conversations.assignAll(list);
    }

    if (Get.isRegistered<FriendsState>()) {
      final friends = Get.find<FriendsState>();
      final list = friends.friends.toList();
      var changed = false;
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == userId && list[i].online != online) {
          list[i] = list[i].copyWithOnline(online);
          changed = true;
        }
      }
      if (changed) friends.friends.assignAll(list);
    }
  }

  void _onTyping(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final userId = _asInt(data['user_id']);
    final isTyping = data['is_typing'] == true;
    final activityRaw = data['activity']?.toString().trim().toLowerCase() ?? '';
    if (chatId == null || userId == null) return;
    if (!Get.isRegistered<ChatState>()) return;
    final chat = Get.find<ChatState>();
    if (chat.chatId.value != chatId) return;
    // DM: faqat peer; guruh: har qanday a'zo (o'zimdan tashqari — server filtrlagan).
    if (!chat.isGroup.value && chat.peerId.value != userId) return;

    chat.peerTyping.value = isTyping;
    chat.typingUserId.value = isTyping ? userId : null;
    chat.peerActivity.value = isTyping
        ? (activityRaw.isNotEmpty ? activityRaw : 'typing')
        : '';
    _typingClearTimer?.cancel();
    if (isTyping) {
      _typingClearTimer = Timer(const Duration(seconds: 4), () {
        if (Get.isRegistered<ChatState>()) {
          final c = Get.find<ChatState>();
          if (c.chatId.value == chatId) {
            c.peerTyping.value = false;
            c.peerActivity.value = '';
            c.typingUserId.value = null;
          }
        }
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _softReloadConversations() async {
    if (!Get.isRegistered<MessagesState>() || !Get.isRegistered<ChatRepository>()) {
      return;
    }
    final messages = Get.find<MessagesState>();
    final filter = messages.listFilter.value;
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
    messages.conversations.assignAll(items);
  }

  String _previewFromMessage(Map<String, dynamic> msg) {
    final type = msg['type']?.toString() ?? 'text';
    final text = (msg['text'] as String?)?.trim();
    if (text != null && text.isNotEmpty) return text;
    return switch (type) {
      'image' => '📷',
      'voice' || 'audio' => '🎤',
      'file' => '📎',
      'product' => '🏷️',
      'location' => '📍',
      'contact' => '👤',
      _ => '',
    };
  }

  @override
  void onClose() {
    _typingClearTimer?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}

ChatMessage mapChatMessageFromApi(
  Map<String, dynamic> json, {
  required int? me,
  String peerName = '',
  ChatReply? fallbackReply,
}) {
  final senderId = (json['sender_id'] as num?)?.toInt();
  final outgoing = me != null && senderId == me;
  final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
  final textTranslated = json['text'] as String?;
  final textOriginal = json['text_original'] as String?;
  final text = _nonEmptyText(textTranslated) ?? _nonEmptyText(textOriginal) ?? '';
  final type = (json['type'] as String?) ?? 'text';
  final reply = _replyFromApi(json, me, peerName) ?? fallbackReply;
  final status = _statusFromApi(json, outgoing: outgoing);
  final ChatMessage mapped;
  if (type == 'voice' || type == 'audio') {
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
    final durationMs = (meta['duration_ms'] as num?)?.toInt();
    final samples = (meta['samples'] as List?)
            ?.whereType<num>()
            .map((e) => e.toDouble())
            .toList() ??
        const <double>[];
    final url = meta['url']?.toString();
    mapped = ChatMessage.voice(
      id: '${json['id']}',
      dir: outgoing ? ChatDir.outgoing : ChatDir.incoming,
      time: formatMessageClock(created),
      createdAt: created,
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
  } else {
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
    final dir = outgoing ? ChatDir.outgoing : ChatDir.incoming;
    final time = formatMessageClock(created);
    final id = '${json['id']}';
    mapped = switch (type) {
      'image' => ChatMessage.image(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          url: meta['url']?.toString(),
          gradient: avatarTealGradient,
          status: status,
          reply: reply,
        ),
      'file' => () {
          final name = meta['filename']?.toString() ?? 'file';
          final size = meta['size'];
          final ext =
              name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
          return ChatMessage.file(
            id: id,
            dir: dir,
            time: time,
            createdAt: created,
            name: name,
            size: size is num ? _formatBytes(size.toInt()) : '—',
            ext: ext,
            url: meta['url']?.toString(),
            status: status,
          );
        }(),
      'product' => ChatMessage.product(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          title: meta['name']?.toString() ??
              meta['product_name']?.toString() ??
              'Mahsulot',
          price: meta['price']?.toString() ?? '—',
          productId: (meta['product_id'] as num?)?.toInt(),
          status: status,
        ),
      'location' => ChatMessage.location(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          label: meta['label']?.toString() ?? 'Joylashuv',
          distance: '',
          latitude: (meta['latitude'] as num?)?.toDouble(),
          longitude: (meta['longitude'] as num?)?.toDouble(),
          status: status,
        ),
      'contact' => () {
          final name = meta['contact_name']?.toString() ?? 'Kontakt';
          return ChatMessage.contact(
            id: id,
            dir: dir,
            time: time,
            createdAt: created,
            name: name,
            phone: meta['contact_phone']?.toString() ?? '',
            initial: initialsOf(name),
            status: status,
          );
        }(),
      _ => ChatMessage.text(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          text: text,
          textOriginal: textOriginal,
          status: status,
          reply: reply,
        ),
    };
  }
  final senderName = json['sender_name']?.toString().trim();
  final senderAvatar = json['sender_avatar_url']?.toString().trim();
  final editedAt = DateTime.tryParse(json['edited_at']?.toString() ?? '');
  final reactions = (json['reactions'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      const <Map<String, dynamic>>[];
  final pinned = json['pinned'] == true;
  return mapped
      .withSenderMeta(
        senderId: senderId,
        senderName: (senderName != null && senderName.isNotEmpty) ? senderName : null,
        senderAvatarUrl:
            (senderAvatar != null && senderAvatar.isNotEmpty) ? senderAvatar : null,
      )
      .withExtras(
        editedAt: editedAt,
        reactions: reactions,
        pinned: pinned,
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

ChatReply? _replyFromApi(
  Map<String, dynamic> json,
  int? me,
  String peerName,
) {
  final nested = asMap(json['reply_to']);
  if (nested == null) return null;
  final senderId = (nested['sender_id'] as num?)?.toInt();
  final author = (me != null && senderId == me)
      ? 'Siz'
      : (nested['sender_name']?.toString().trim().isNotEmpty == true
          ? nested['sender_name'].toString()
          : peerName);
  final deleted = nested['is_deleted'] == true;
  final previewRaw = nested['preview_text']?.toString().trim();
  final previewText = deleted
      ? 'O‘chirilgan xabar'
      : ((previewRaw != null && previewRaw.isNotEmpty) ? previewRaw : 'Xabar');
  final id = nested['id'];
  return ChatReply(
    author: author,
    preview: previewText,
    messageId: id == null ? null : '$id',
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String? _nonEmptyText(String? value) {
  final t = value?.trim();
  if (t == null || t.isEmpty) return null;
  return value;
}
