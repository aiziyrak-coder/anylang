import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../modal/attachment_bottom_sheet.dart';
import '../../modal/message_actions_sheet.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'chat_action.dart';
import 'chat_content.dart';
import 'chat_message.dart';
import 'chat_payload.dart';
import 'chat_state.dart';

class ChatScreen extends Screen<ChatState, ChatPayload> {
  ChatScreen()
      : super(
          mobileContent: ChatContent(),
        );

  int _seq = 0;

  @override
  void initState(ChatPayload? payload) {
    final p = payload ?? kAnnaChat;
    state.peerName = p.name;
    state.peerInitial = p.initial;
    state.peerAvatar = p.avatarGradient;
    state.peerOnline = p.online;

    // ChatState fenix-singleton — har ochilishda avvalgi holatni tozalaymiz.
    state.input.value = '';
    state.replyTo.value = null;
    state.recording.value = false;

    // TODO: xabarlarni backend/DB'dan yuklash. Hozircha mock (dizayn holati).
    state.messages
      ..clear()
      ..addAll(_mockThread(p));
  }

  @override
  Future<void> actionHandler(ChatState state, MyAction action) async {
    switch (action) {
      case InputChanged a:
        state.input.value = a.text;

      case SendText _:
        final text = state.input.value.trim();
        if (text.isEmpty) return;
        state.messages.add(
          ChatMessage.text(
            id: _nextId(),
            dir: ChatDir.outgoing,
            time: _now(),
            text: text,
            status: ChatStatus.sent,
            reply: _replyFor(state),
          ),
        );
        state.input.value = '';
        state.replyTo.value = null;

      case OpenAttachMenu _:
        final kind = await showAttachmentBottomSheet(context);
        if (kind != null) sendAction(PickAttachment(kind));

      case PickAttachment a:
        state.messages.add(_attachmentMessage(a.kind));

      case LongPressMessage a:
        final msg = a.message;
        final showTranslate =
            msg.type == ChatMsgType.text && !msg.isOutgoing;
        final chosen = await showMessageActionsSheet(
          context,
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
        state.messages.removeWhere((m) => m.id == a.message.id);

      case StartRecording _:
        state.recording.value = true;

      case CancelRecording _:
        state.recording.value = false;

      case SendVoice _:
        state.messages.add(
          ChatMessage.voice(
            id: _nextId(),
            dir: ChatDir.outgoing,
            time: _now(),
            duration: '0:03',
            status: ChatStatus.sent,
          ),
        );
        state.recording.value = false;

      case Back _:
        popBackNavigate();
    }
  }

  // ---------------------------------------------------------------------------
  // Yordamchilar
  // ---------------------------------------------------------------------------

  String _nextId() => 'm${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  String _now() {
    final t = DateTime.now();
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Joriy reply holatidan `ChatReply` sitatasini yasaydi.
  ChatReply? _replyFor(ChatState state) {
    final r = state.replyTo.value;
    if (r == null) return null;
    return ChatReply(
      author: r.isOutgoing ? 'chat_you'.tr : state.peerName,
      preview: r.previewText(),
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
          gradient: prodTealGradient,
          status: ChatStatus.sent,
        );
      case AttachKind.file:
        return ChatMessage.file(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          name: 'Hujjat.pdf',
          size: '248 KB',
          ext: 'PDF',
          status: ChatStatus.sent,
        );
      case AttachKind.product:
        return ChatMessage.product(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          title: 'Qo\'lda to\'qilgan sharf',
          price: '\$24.00',
          status: ChatStatus.sent,
        );
      case AttachKind.location:
        return ChatMessage.location(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          label: 'chat_my_location'.tr,
          distance: '1.2 km',
          status: ChatStatus.sent,
        );
      case AttachKind.contact:
        return ChatMessage.contact(
          id: id,
          dir: ChatDir.outgoing,
          time: time,
          name: 'Doniyor Karimov',
          phone: '+998 90 123 45 67',
          initial: 'DK',
          status: ChatStatus.sent,
        );
    }
  }

  void _toast(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }

  /// Namuna suhbat (dizayndagi barcha xabar turlari). Keyinchalik backend.
  List<ChatMessage> _mockThread(ChatPayload p) {
    final incoming = ChatMessage.text(
      id: _nextId(),
      dir: ChatDir.incoming,
      time: '14:30',
      text: 'Salom! Buyurtmangiz tayyor bo\'ldi 🎉',
    );
    return [
      incoming,
      ChatMessage.text(
        id: _nextId(),
        dir: ChatDir.outgoing,
        time: '14:32',
        text: 'Rahmat! Hoziroq yetib boraman.',
        status: ChatStatus.read,
        reply: ChatReply(author: p.name, preview: incoming.previewText()),
      ),
      ChatMessage.voice(
        id: _nextId(),
        dir: ChatDir.incoming,
        time: '14:33',
        duration: '0:21',
        downloaded: false,
      ),
      ChatMessage.voice(
        id: _nextId(),
        dir: ChatDir.incoming,
        time: '14:33',
        duration: '0:38',
      ),
      ChatMessage.file(
        id: _nextId(),
        dir: ChatDir.incoming,
        time: '14:34',
        name: 'Shartnoma.pdf',
        size: '248 KB',
        ext: 'PDF',
      ),
      ChatMessage.contact(
        id: _nextId(),
        dir: ChatDir.incoming,
        time: '14:35',
        name: 'Doniyor Karimov',
        phone: '+998 90 123 45 67',
        initial: 'DK',
      ),
    ];
  }
}
