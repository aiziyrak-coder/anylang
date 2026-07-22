import '../../utils/screen_options/my_action.dart';
import 'add_friend_result.dart';

/// Faqat "Qo'shish" ekraniga xos action'lar.
class AddFriendAction extends MyAction {}

/// Qidiruv matni o'zgarganda.
class AddFriendSearchChanged extends AddFriendAction {
  final String text;
  AddFriendSearchChanged(this.text);
}

/// Xabarlar rejimi: natija ustiga bosilganda chat.
class OpenUserChat extends AddFriendAction {
  final AddFriendResult result;
  OpenUserChat(this.result);
}

/// Do'stlar rejimi: "Qo'shish" — so'rov yuborish.
class SendFriendRequest extends AddFriendAction {
  final AddFriendResult result;
  SendFriendRequest(this.result);
}

/// Do'stlar rejimi: "Yozish" (allaqachon do'st).
class MessageResult extends AddFriendAction {
  final AddFriendResult result;
  MessageResult(this.result);
}
