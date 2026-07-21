import '../../utils/screen_options/my_action.dart';
import 'add_friend_result.dart';

/// Faqat "Do'st qo'shish" ekraniga xos action'lar.
class AddFriendAction extends MyAction {}

/// Qidiruv matni o'zgarganda.
class AddFriendSearchChanged extends AddFriendAction {
  final String text;
  AddFriendSearchChanged(this.text);
}

/// "Qo'shish" tugmasi.
class SendFriendRequest extends AddFriendAction {
  final AddFriendResult result;
  SendFriendRequest(this.result);
}

/// "Yozish" tugmasi (allaqachon do'st).
class MessageResult extends AddFriendAction {
  final AddFriendResult result;
  MessageResult(this.result);
}
