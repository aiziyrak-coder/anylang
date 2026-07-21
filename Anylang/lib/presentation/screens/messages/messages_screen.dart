import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import 'conversation.dart';
import 'messages_action.dart';
import 'messages_content.dart';
import 'messages_state.dart';

class MessagesScreen extends Screen<MessagesState, void> {

  MessagesScreen() : super(
    mobileContent: MessagesContent(),
  );

  @override
  void initState(void payload) {
    // TODO: suhbatlarni backenddan yuklash. Hozircha mock.
    state.conversations.addAll(kMockConversations);
  }

  @override
  Future<void> actionHandler(MessagesState state, MyAction action) async {
    switch (action) {
      case SearchChanged a:
        state.query.value = a.text;
      case OpenConversation a:
        final conv = a.conversation;
        navigate(
          ChatScreen(),
          payload: ChatPayload(
            name: conv.name,
            initial: conv.initial,
            avatarGradient: conv.avatarGradient,
            online: conv.online,
          ),
        );
      case NewConversation _:
        // TODO: yangi suhbat oqimi.
        break;
    }
  }
}
