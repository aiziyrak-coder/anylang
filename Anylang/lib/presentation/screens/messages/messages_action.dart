import '../../utils/screen_options/my_action.dart';
import '../add_friend/add_friend_result.dart';
import 'conversation.dart';

/// Faqat Xabarlar ekraniga xos action'lar.
class MessagesAction extends MyAction {}

/// Qidiruv matni o'zgarganda.
class SearchChanged extends MessagesAction {
  final String text;
  SearchChanged(this.text);
}

/// Suhbat ochilganda.
class OpenConversation extends MessagesAction {
  final Conversation conversation;
  OpenConversation(this.conversation);
}

/// "+" tugmasi — yangi suhbat.
class NewConversation extends MessagesAction {}

class RefreshConversations extends MessagesAction {}

/// Qidiruvdan foydalanuvchi bilan suhbat ochish.
class OpenUserChat extends MessagesAction {
  final AddFriendResult user;
  OpenUserChat(this.user);
}
