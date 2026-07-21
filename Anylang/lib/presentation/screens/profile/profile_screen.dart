import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_product/add_product_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';
import 'profile_account.dart';
import 'profile_action.dart';
import 'profile_content.dart';
import 'profile_state.dart';

class ProfileScreen extends Screen<ProfileState, void> {

  ProfileScreen() : super(
    mobileContent: ProfileContent(),
  );

  @override
  void initState(void payload) {
    // TODO: joriy foydalanuvchi profilini backenddan yuklash. Hozircha mock.
    state.account.value = kMockPersonalAccount;
  }

  @override
  Future<void> actionHandler(ProfileState state, MyAction action) async {
    switch (action) {
      case OpenSubscription _:
        navigate(SubscriptionScreen());
      case OpenSettings _:
        navigate(SettingsScreen());
      case EditPersonalProfile _:
        navigate(ProfileEditScreen(), payload: state.account.value);
      case EditBusinessInfo _:
        navigate(EditBusinessInfoScreen());
      case AddProductRequested _:
        navigate(AddProductScreen());
      case SeeAllListings _:
        // TODO: barcha e'lonlar ekrani.
        break;
      case OpenOwnListing _:
        // TODO: e'lon tahrirlash/ko'rish ekrani.
        break;
    }
  }
}
