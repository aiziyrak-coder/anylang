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
  final bool isGroup;
  final bool showSenderName;
  final bool showAvatar;

  LongPressMessage(
    this.message,
    this.anchor, {
    this.isGroup = false,
    this.showSenderName = false,
    this.showAvatar = false,
  });
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
  final bool forEveryone;
  DeleteMessage(this.message, {this.forEveryone = false});
}

/// Xabarni tahrirlash.
class EditMessage extends ChatAction {
  final ChatMessage message;
  EditMessage(this.message);
}

/// Pin / unpin.
class ToggleMessagePin extends ChatAction {
  final ChatMessage message;
  ToggleMessagePin(this.message);
}

/// Reaksiya.
class ReactToMessage extends ChatAction {
  final ChatMessage message;
  final String emoji;
  ReactToMessage(this.message, this.emoji);
}

/// Tanlash rejimi.
class EnterSelectMode extends ChatAction {
  final ChatMessage? seed;
  EnterSelectMode([this.seed]);
}

class ExitSelectMode extends ChatAction {}

class ToggleSelectMessage extends ChatAction {
  final ChatMessage message;
  ToggleSelectMessage(this.message);
}

class ForwardSelectedMessages extends ChatAction {}

class DeleteSelectedMessages extends ChatAction {}

class CancelForwardDraft extends ChatAction {}

class ToggleForwardShowSender extends ChatAction {}

/// Guruh sozlamalari.
class OpenGroupSettings extends ChatAction {}

/// Mikrofon — ovoz yozishni boshlash (composer record holatiga o'tadi).
class StartRecording extends ChatAction {}

/// Yozishni bekor qilish (savat).
class CancelRecording extends ChatAction {}

/// Yozilgan ovozni yuborish.
class SendVoice extends ChatAction {}

/// App bar ⋮ — suhbat menyusi (anchor bilan oynacha).
class OpenChatMenu extends ChatAction {
  final Rect anchor;
  OpenChatMenu(this.anchor);
}

/// Suhbatdosh profilini ochish (avatar / ism / menyu).
class OpenPeerProfile extends ChatAction {}

/// Chat ichida qidiruv rejimini yoqish/o‘chirish.
class ToggleChatSearch extends ChatAction {}

/// Qidiruv matni.
class ChatSearchChanged extends ChatAction {
  final String text;
  ChatSearchChanged(this.text);
}

/// Bildirishnomalarni o‘chirish / yoqish.
class ToggleChatMute extends ChatAction {}

/// Suhbatni yuqoriga qadash / olish.
class ToggleChatPin extends ChatAction {}

/// Tarixni tozalash (men uchun).
class ClearChatHistory extends ChatAction {}

/// Suhbatni o‘chirish (tozalash + chiqish).
class DeleteChat extends ChatAction {}

/// Foydalanuvchini bloklash.
class BlockPeer extends ChatAction {}

/// Chat xabaridagi mahsulot kartasini ochish.
class OpenChatProduct extends ChatAction {
  final ChatMessage message;
  OpenChatProduct(this.message);
}

/// Guruhda yuboruvchi avatar/ismiga bosilganda profil.
class OpenSenderProfile extends ChatAction {
  final int userId;
  OpenSenderProfile(this.userId);
}

class JoinGroupInvite extends ChatAction {
  final String token;
  JoinGroupInvite(this.token);
}
