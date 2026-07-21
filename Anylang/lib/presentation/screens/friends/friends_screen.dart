import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_friend/add_friend_screen.dart';
import 'friend.dart';
import 'friends_action.dart';
import 'friends_content.dart';
import 'friends_state.dart';

class FriendsScreen extends Screen<FriendsState, void> {

  FriendsScreen() : super(
    mobileContent: FriendsContent(),
  );

  @override
  void initState(void payload) {
    // TODO: do'stlarni backenddan yuklash. Hozircha mock.
    state.friends.addAll(kMockFriends);
  }

  @override
  Future<void> actionHandler(FriendsState state, MyAction action) async {
    switch (action) {
      case FriendsSearchChanged a:
        state.query.value = a.text;
      case OpenChat _:
        // TODO: suhbat ekranini ochish.
        break;
      case AddFriend _:
        navigate(AddFriendScreen());
    }
  }
}
