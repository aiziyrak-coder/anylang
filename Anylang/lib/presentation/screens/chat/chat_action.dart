import 'package:flutter/material.dart';

import '../../utils/screen_options/my_action.dart';
import 'chat_message.dart';

/// Biriktirish menyusidagi variantlar (3b).
enum AttachKind { gallery, camera, file, product, location, contact }

/// Faqat Chat (suhbat) ekraniga xos action'lar.
class ChatAction extends MyAction {}

/// Input matni o'zgarganda (mic ↔ yuborish tugmasi almashadi).
class InputChanged extends ChatAction {
  final String text;
  InputChanged(this.text);
}

/// Matnli xabar yuborish.
class SendText extends ChatAction {}

/// "+" — biriktirish menyusini ochish (3b).
class OpenAttachMenu extends ChatAction {}

/// Biriktirish menyusidan tur tanlanganda (mock xabar qo'shiladi).
class PickAttachment extends ChatAction {
  final AttachKind kind;
  PickAttachment(this.kind);
}

/// Xabar ustiga uzoq bosilganda — kontekst menyusi (3c / 3g). `anchor` —
/// bosilgan xabar pufakchasining ekrandagi joylashuvi.
class LongPressMessage extends ChatAction {
  final ChatMessage message;
  final Rect anchor;
  LongPressMessage(this.message, this.anchor);
}

/// "Javob berish" — reply rejimini yoqish.
class StartReply extends ChatAction {
  final ChatMessage message;
  StartReply(this.message);
}

/// Reply rejimini bekor qilish.
class CancelReply extends ChatAction {}

/// "Nusxa olish".
class CopyMessage extends ChatAction {
  final ChatMessage message;
  CopyMessage(this.message);
}

/// "O'chirish".
class DeleteMessage extends ChatAction {
  final ChatMessage message;
  DeleteMessage(this.message);
}

/// Mikrofon — ovoz yozishni boshlash (composer record holatiga o'tadi).
class StartRecording extends ChatAction {}

/// Yozishni bekor qilish (savat).
class CancelRecording extends ChatAction {}

/// Yozilgan ovozni yuborish.
class SendVoice extends ChatAction {}
