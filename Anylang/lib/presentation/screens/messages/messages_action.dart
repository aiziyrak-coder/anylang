import '../../utils/screen_options/my_action.dart';
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
