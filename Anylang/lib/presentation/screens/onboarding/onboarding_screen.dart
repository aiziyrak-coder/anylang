import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../login/login_screen.dart';
import 'onboarding_action.dart';
import 'onboarding_content.dart';
import 'onboarding_state.dart';

class OnboardingScreen extends Screen<OnboardingState, void> {

  OnboardingScreen() : super(
    mobileContent: OnboardingContent(),
  );

  @override
  Future<void> actionHandler(OnboardingState state, MyAction action) async {
    switch (action) {
      case PageChanged a:
        state.currentPage.value = a.index;
      case SkipOnboarding _:
        navigate(LoginScreen());
      case Continue _:
        navigate(LoginScreen());
    }
  }
}
