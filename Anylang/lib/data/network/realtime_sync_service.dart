import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../audio/message_alert_sound_service.dart';
import '../audio/waveform_utils.dart';
import '../core/mappers.dart';
import '../local/session_store.dart';
import 'chat_repository.dart';
import 'socket_service.dart';
import '../../presentation/modal/new_device_alert_dialog.dart';
import '../../presentation/screens/devices/devices_screen.dart';
import '../../presentation/screens/chat/chat_message.dart';
import '../../presentation/screens/chat/chat_state_scope.dart';
import '../../presentation/screens/friends/friends_state.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/messages/conversation.dart';
import '../../presentation/screens/messages/messages_state.dart';
import '../../presentation/ui/theme/gradients.dart';
import '../core/buildNetwork/api_service.dart';
import 'auth_repository.dart';

/// WebSocket eventlarini GetX state'larga ulaydi.
/// SocketService faqat stream beradi — tinglash shu yerda.
class RealtimeSyncService extends GetxService {
  StreamSubscription<Map<String, dynamic>>? _sub;
  int? _activeChatId;
  Timer? _typingClearTimer;
  Timer? _rebindDebounce;

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
      onError: (e) {
        debugPrint('RealtimeSync error: $e');
        _rebindDebounce?.cancel();
        _rebindDebounce = Timer(const Duration(seconds: 2), rebind);
      },
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
      case 'device_login':
        _onDeviceLogin(data);
      case 'session_revoked':
        _onSessionRevoked(data);
      default:
        break;
    }
  }

  void _onDeviceLogin(Map<String, dynamic> data) {
    final sid = data['session_id']?.toString();
    if (sid != null &&
        sid.isNotEmpty &&
        sid == SessionStore.sessionId) {
      return;
    }
    final name = (data['device_name']?.toString() ?? '').trim();
    final deviceName =
        name.isEmpty ? 'device_fallback_mobile'.tr : name;
    Future.microtask(() async {
      final ctx = Get.overlayContext;
      if (ctx == null || !ctx.mounted) return;
      await showNewDeviceAlertDialog(
        ctx,
        deviceName: deviceName,
        onOpenDevices: () {
          // Profil stack ustida ochish — oddiy Get push.
          final nav = Navigator.of(ctx, rootNavigator: true);
          nav.push(
            MaterialPageRoute(builder: (_) => DevicesScreen().build()),
          );
        },
      );
    });
  }

  void _onSessionRevoked(Map<String, dynamic> data) {
    final sid = data['session_id']?.toString();
    final mine = SessionStore.sessionId;
    if (sid == null || mine == null || sid != mine) return;
    Future.microtask(() async {
      try {
        await Get.find<AuthRepository>().logout();
      } catch (_) {
        await SessionStore.clear();
      }
      if (Get.isRegistered<SessionExpiredBus>()) {
        Get.find<SessionExpiredBus>().notify();
      } else {
        Get.offAll(() => LoginScreen().build());
      }
    });
  }

  void _onMessageEdited(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final msgMap = asMap(data['message']);
    if (chatId == null || msgMap == null) return;
    ChatStateScope.forChatId(chatId, (chat) {
      final mapped = mapChatMessageFromApi(msgMap, me: SessionStore.userId(), peerName: chat.peerName.value);
      final idx = chat.messages.indexWhere((m) => m.id == mapped.id);
      if (idx >= 0) {
        final prevShowing = chat.messages[idx].showingOriginal;
        chat.messages[idx] = mapped.withShowingOriginal(prevShowing);
      }
    });
  }

  void _onMessageReaction(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final messageId = '${data['message_id']}';
    if (chatId == null) return;
    final reactions = (data['reactions'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    ChatStateScope.forChatId(chatId, (chat) {
      final idx = chat.messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        chat.messages[idx] = chat.messages[idx].withReactions(reactions);
      }
    });
  }

  void _onMessagePinEvent(Map<String, dynamic> data, {required bool pinned}) {
    final chatId = _asInt(data['chat_id']);
    final messageId = '${data['message_id']}';
    if (chatId == null) return;
    ChatStateScope.forChatId(chatId, (chat) {
      final idx = chat.messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final msg = chat.messages[idx].withPinned(pinned);
        chat.messages[idx] = msg;
        if (pinned) {
          chat.pinnedMessages.removeWhere((m) => m.id == messageId);
          chat.pinnedMessages.add(msg);
          chat.pinnedBanner.value = msg;
        } else {
          chat.pinnedMessages.removeWhere((m) => m.id == messageId);
          chat.pinnedBanner.value = chat.pinnedMessages.isNotEmpty
              ? chat.pinnedMessages.last
              : null;
        }
      }
    });
  }

  void _onHistoryCleared(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    if (chatId == null) return;
    ChatStateScope.forChatId(chatId, (chat) {
      if (data['for_everyone'] == true) {
        chat.messages.clear();
        chat.pinnedBanner.value = null;
        chat.pinnedMessages.clear();
      }
    });
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

    // Open chat → append / merge (nested chat stackdagi barcha mos state).
    var appliedToOpenChat = false;
    ChatStateScope.forChatId(chatId, (chat) {
      appliedToOpenChat = true;
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
        final prevShowing = chat.messages[idx].showingOriginal;
        final prev = chat.messages[idx];
        var next = mapped.withShowingOriginal(prevShowing);
        // Lokal pending ovoz — server URL kelguncha lokal path/samples saqlansin.
        if (prev.type == ChatMsgType.voice && mapped.type == ChatMsgType.voice) {
          next = ChatMessage.voice(
            id: mapped.id,
            dir: mapped.dir,
            time: mapped.time,
            createdAt: mapped.createdAt,
            duration: mapped.voiceDuration ?? prev.voiceDuration ?? '0:00',
            durationMs: mapped.voiceDurationMs ?? prev.voiceDurationMs,
            path: (mapped.voicePath != null && mapped.voicePath!.isNotEmpty)
                ? mapped.voicePath
                : prev.voicePath,
            samples: mapped.voiceSamples.isNotEmpty
                ? mapped.voiceSamples
                : prev.voiceSamples,
            downloaded: mapped.voiceDownloaded || prev.voiceDownloaded,
            status: mapped.status,
            reply: mapped.reply ?? prev.reply,
            senderId: mapped.senderId,
            senderName: mapped.senderName,
            senderAvatarUrl: mapped.senderAvatarUrl,
            text: mapped.text,
            textOriginal: mapped.textOriginal,
            showingOriginal: prevShowing,
            transcriptPending: mapped.transcriptPending,
            transcriptFailed: mapped.transcriptFailed,
          );
        }
        chat.messages[idx] = next;
      } else {
        chat.messages.add(mapped);
      }
      if (!isMine) {
        chat.peerTyping.value = false;
        chat.peerActivity.value = '';
      }
    });
    if (appliedToOpenChat && !isMine) {
      final id = int.tryParse(msgId);
      if (id != null) {
        Get.find<ChatRepository>().markRead(chatId, [id]);
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

    _maybePlayIncomingSound(chatId: chatId, isMine: isMine);
  }

  void _maybePlayIncomingSound({required int chatId, required bool isMine}) {
    if (isMine) return;
    // Ochiq chatda o‘qilayotgan suhbat — tovushsiz.
    if (_activeChatId == chatId) return;
    if (!SessionStore.newMessagesNotificationsEnabled()) return;
    if (SessionStore.isChatMuted(chatId)) return;
    if (Get.isRegistered<MessagesState>()) {
      final list = Get.find<MessagesState>().conversations;
      final i = list.indexWhere((c) => c.id == chatId);
      if (i >= 0 && list[i].muted) return;
    }
    if (!Get.isRegistered<MessageAlertSoundService>()) return;
    unawaited(Get.find<MessageAlertSoundService>().play());
  }

  void _onMessagesRead(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final ids = (data['message_ids'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};
    if (chatId == null || ids.isEmpty) return;
    ChatStateScope.forChatId(chatId, (chat) {
      for (var i = 0; i < chat.messages.length; i++) {
        final m = chat.messages[i];
        if (m.isOutgoing && ids.contains(m.id)) {
          chat.messages[i] = m.withStatus(ChatStatus.read);
        }
      }
    });
  }

  void _onMessageDeleted(Map<String, dynamic> data) {
    final chatId = _asInt(data['chat_id']);
    final messageId = data['message_id']?.toString();
    if (chatId == null || messageId == null) return;
    ChatStateScope.forChatId(chatId, (chat) {
      chat.messages.removeWhere((m) => m.id == messageId);
    });
    unawaited(_softReloadConversations());
  }

  void _onPresence(Map<String, dynamic> data) {
    final userId = _asInt(data['user_id']);
    final online = data['is_online'] == true;
    if (userId == null) return;

    for (final chat in ChatStateScope.all) {
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
    ChatStateScope.forChatId(chatId, (chat) {
      // DM: faqat peer; guruh: har qanday a'zo (o'zimdan tashqari — server filtrlagan).
      if (!chat.isGroup.value && chat.peerId.value != userId) return;

      chat.peerTyping.value = isTyping;
      chat.typingUserId.value = isTyping ? userId : null;
      chat.peerActivity.value = isTyping
          ? (activityRaw.isNotEmpty ? activityRaw : 'typing')
          : '';
    });
    _typingClearTimer?.cancel();
    if (isTyping) {
      _typingClearTimer = Timer(const Duration(seconds: 4), () {
        ChatStateScope.forChatId(chatId, (c) {
          c.peerTyping.value = false;
          c.peerActivity.value = '';
          c.typingUserId.value = null;
        });
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
      'invoice' => '🧾',
      'catalog' => '📚',
      'offer' => '🤝',
      'rfq' => '📣',
      'business_card' => '🪪',
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
    final hasText = text.trim().isNotEmpty;
    final sttStatus = meta['transcription_status']?.toString();
    // STT 45s dan oshsa yoki failed — shimmer o‘rniga xato matni.
    const sttTimeout = Duration(seconds: 45);
    final age = created != null
        ? DateTime.now().toUtc().difference(created.toUtc())
        : Duration.zero;
    final stale = age > sttTimeout;
    final transcriptFailed = sttStatus == 'failed' ||
        (!hasText && (sttStatus == 'pending' || sttStatus == null) && stale);
    final transcriptPending =
        !transcriptFailed && !hasText && !stale;
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
      text: textTranslated,
      textOriginal: textOriginal,
      transcriptPending: transcriptPending,
      transcriptFailed: transcriptFailed,
    );
  } else if (type == 'video') {
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
    final durationMs = (meta['duration_ms'] as num?)?.toInt();
    final url = meta['url']?.toString();
    final hasText = text.trim().isNotEmpty;
    final sttStatus = meta['transcription_status']?.toString();
    const sttTimeout = Duration(seconds: 90);
    final age = created != null
        ? DateTime.now().toUtc().difference(created.toUtc())
        : Duration.zero;
    final stale = age > sttTimeout;
    final transcriptFailed = sttStatus == 'failed' ||
        (!hasText && (sttStatus == 'pending' || sttStatus == null) && stale);
    final transcriptPending = !transcriptFailed && !hasText && !stale;
    mapped = ChatMessage.video(
      id: '${json['id']}',
      dir: outgoing ? ChatDir.outgoing : ChatDir.incoming,
      time: formatMessageClock(created),
      createdAt: created,
      url: url,
      isRoundNote: meta['is_round_note'] == true,
      duration: durationMs != null
          ? WaveformUtils.formatDuration(Duration(milliseconds: durationMs))
          : null,
      durationMs: durationMs,
      status: status,
      reply: reply,
      text: textTranslated,
      textOriginal: textOriginal,
      transcriptPending: transcriptPending,
      transcriptFailed: transcriptFailed,
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
            userId: (meta['contact_user_id'] as num?)?.toInt(),
            avatarUrl: meta['contact_avatar_url']?.toString(),
            number: meta['contact_number']?.toString(),
          );
        }(),
      'invoice' => ChatMessage.invoice(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          title: meta['title']?.toString() ??
              meta['name']?.toString() ??
              'Invoice',
          amount: [
            meta['amount']?.toString() ?? '',
            meta['currency']?.toString() ?? '',
          ].where((e) => e.isNotEmpty).join(' '),
          note: meta['note']?.toString() ?? meta['description']?.toString(),
          status: status,
        ),
      'catalog' => ChatMessage.catalog(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          title: meta['title']?.toString() ??
              meta['company_name']?.toString() ??
              'Catalog',
          subtitle: meta['subtitle']?.toString() ??
              ((meta['count'] != null)
                  ? '${meta['count']} products'
                  : ''),
          detail: meta['preview']?.toString() ??
              (meta['items'] is List
                  ? (meta['items'] as List).take(4).join(' · ')
                  : null),
          imageUrl: meta['image_url']?.toString(),
          status: status,
        ),
      'business_card' => ChatMessage.businessCard(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          name: meta['name']?.toString() ??
              meta['company_name']?.toString() ??
              'Card',
          company: meta['company_name']?.toString(),
          role: meta['role']?.toString() ?? meta['business_role']?.toString(),
          phone: meta['phone']?.toString(),
          imageUrl: meta['avatar_url']?.toString() ?? meta['logo_url']?.toString(),
          userId: (meta['user_id'] as num?)?.toInt(),
          status: status,
        ),
      'offer' => ChatMessage.offer(
          id: id,
          dir: dir,
          time: time,
          createdAt: created,
          product: meta['product']?.toString() ??
              meta['product_name']?.toString() ??
              'Product',
          price: meta['price']?.toString() ?? '',
          currency: meta['currency']?.toString(),
          delivery: meta['delivery']?.toString() ??
              meta['lead_time']?.toString(),
          moq: meta['moq']?.toString(),
          payment: meta['payment']?.toString() ??
              meta['payment_terms']?.toString(),
          status: meta['status']?.toString() ?? 'offered',
          productId: (meta['product_id'] as num?)?.toInt(),
          chatStatus: status,
        ),
      'rfq' => () {
          final unitRaw = meta['unit']?.toString() ?? 'pcs';
          final unitKey = 'chat_rfq_unit_$unitRaw';
          final unitLabel = unitKey.tr == unitKey ? unitRaw : unitKey.tr;
          return ChatMessage.rfq(
            id: id,
            dir: dir,
            time: time,
            createdAt: created,
            product: meta['product']?.toString() ??
                meta['product_name']?.toString() ??
                'Product',
            quantity: meta['quantity']?.toString() ?? '',
            unit: unitLabel,
            specs: meta['specs']?.toString() ?? meta['details']?.toString(),
            deadline: meta['deadline']?.toString(),
            chatStatus: status,
            reply: reply,
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
          isAiFaq: meta['ai_faq'] == true,
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
  AutoBusinessCard? autoCard;
  final cardRaw = json['auto_business_card'];
  if (cardRaw is Map && !outgoing) {
    autoCard = AutoBusinessCard.fromApi(Map<String, dynamic>.from(cardRaw));
  }
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
        autoBusinessCard: autoCard,
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
