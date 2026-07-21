import '../../utils/screen_options/my_action.dart';

/// Faqat Onboarding ekraniga xos action'lar.
class OnboardingAction extends MyAction {}

class PageChanged extends OnboardingAction {
  final int index;
  PageChanged(this.index);
}

class SkipOnboarding extends OnboardingAction {}
