import 'package:flutter/material.dart';

import '../../utils/screen_options/my_action.dart';
import '../add_friend/add_friend_result.dart';
import 'conversation.dart';
import 'messages_state.dart';

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

/// "+" tugmasi — yangi suhbat / guruh oynachasi.
class NewConversation extends MessagesAction {
  final Rect anchor;
  NewConversation(this.anchor);
}

class NewGroupRequested extends MessagesAction {}

class RefreshConversations extends MessagesAction {}

/// Qidiruvdan foydalanuvchi bilan suhbat ochish.
class OpenUserChat extends MessagesAction {
  final AddFriendResult user;
  OpenUserChat(this.user);
}

/// Filter bari — bir vaqtda faqat bitta.
class ChangeMessagesFilter extends MessagesAction {
  final MessagesListFilter filter;
  ChangeMessagesFilter(this.filter);
}

/// Suhbatdosh item long-press — kontekst oynachasi.
class LongPressConversation extends MessagesAction {
  final Conversation conversation;
  final Rect anchor;
  LongPressConversation(this.conversation, this.anchor);
}

class EnterListSelect extends MessagesAction {
  final Conversation seed;
  EnterListSelect(this.seed);
}

class ToggleListSelect extends MessagesAction {
  final Conversation conversation;
  ToggleListSelect(this.conversation);
}

class ExitListSelect extends MessagesAction {}

class BulkMuteSelected extends MessagesAction {}

class BulkHideSelected extends MessagesAction {}

class BulkDeleteSelected extends MessagesAction {}
