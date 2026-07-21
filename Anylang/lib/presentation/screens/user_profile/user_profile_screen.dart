import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../products/product_info_bottom_sheet.dart';
import 'user_profile_action.dart';
import 'user_profile_content.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileScreen extends Screen<UserProfileState, UserProfilePayload> {

  UserProfileScreen() : super(
    mobileContent: UserProfileContent(),
  );

  @override
  void initState(UserProfilePayload? payload) {
    state.data = payload;
  }

  @override
  Future<void> actionHandler(UserProfileState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case WriteMessage _:
        // TODO: suhbat ekranini ochish.
        break;
      case CallUser _:
        // TODO: telefon qilish.
        break;
      case OpenWebsite _:
        // TODO: veb-saytni ochish.
        break;
      case OpenListing a:
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () =>
              navigate(UserProfileScreen(), payload: kAnadoluBusinessProfile),
        );
    }
  }
}
