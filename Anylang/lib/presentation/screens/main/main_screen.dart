import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'main_action.dart';
import 'main_content.dart';
import 'main_state.dart';

class MainScreen extends Screen<MainState, void> {

  MainScreen() : super(
    mobileContent: MainContent(),
  );

  @override
  Future<void> actionHandler(MainState state, MyAction action) async {
    switch (action) {
      case TabSelected a:
        state.currentTab.value = a.index;
    }
  }
}
