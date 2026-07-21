import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'add_friend_action.dart';
import 'add_friend_content.dart';
import 'add_friend_result.dart';
import 'add_friend_state.dart';

class AddFriendScreen extends Screen<AddFriendState, void> {

  AddFriendScreen() : super(
    mobileContent: AddFriendContent(),
  );

  @override
  void initState(void payload) {
    // TODO: natijalarni backenddan qidirish. Hozircha mock.
    state.results.addAll(kMockAddFriendResults);
  }

  @override
  Future<void> actionHandler(AddFriendState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case AddFriendSearchChanged a:
        state.query.value = a.text;
      case SendFriendRequest _:
        // TODO: do'stlik so'rovini yuborish.
        break;
      case MessageResult _:
        // TODO: suhbat ekranini ochish.
        break;
    }
  }
}
