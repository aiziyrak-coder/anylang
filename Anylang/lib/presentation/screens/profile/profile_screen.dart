import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
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
  ProfileScreen() : super(mobileContent: ProfileContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.account.value = ProfileAccount.fromApi(map);
      },
      failure: showAppError,
    );
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
        break;
      case OpenOwnListing _:
        break;
    }
  }
}
