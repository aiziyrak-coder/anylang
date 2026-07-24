import 'package:get/get.dart';
import '../presentation/screens/add_friend/add_friend_state.dart';
import '../presentation/screens/create_group/create_group_screen.dart';
import '../presentation/screens/chat/chat_state.dart';
import '../presentation/screens/add_product/add_product_state.dart';
import '../presentation/screens/edit_business_info/edit_business_info_state.dart';
import '../presentation/screens/friends/friends_state.dart';
import '../presentation/screens/jonli/jonli_state.dart';
import '../presentation/screens/login/login_state.dart';
import '../presentation/screens/main/main_state.dart';
import '../presentation/screens/messages/messages_state.dart';
import '../presentation/screens/numbers/numbers_state.dart';
import '../presentation/screens/products/products_state.dart';
import '../presentation/screens/profile/profile_state.dart';
import '../presentation/screens/profile_edit/profile_edit_state.dart';
import '../presentation/screens/settings/settings_state.dart';
import '../presentation/screens/subscription/subscription_state.dart';
import '../presentation/screens/user_profile/user_profile_state.dart';
import '../presentation/screens/onboarding/onboarding_state.dart';
import '../presentation/screens/register/register_state.dart';
import '../presentation/screens/select_language/select_language_state.dart';
import '../presentation/screens/forgot_password/forgot_password_screen.dart';
import '../presentation/screens/restore_account/restore_account_screen.dart';
import '../presentation/screens/group_settings/group_settings_state.dart';
import '../presentation/screens/verify/verify_state.dart';
import '../presentation/screens/support_chat/support_chat_state.dart';

class StatesModule {

  Future<void> initModule() async {
    Get.lazyPut<SelectLanguageState>(() => SelectLanguageState(), fenix: true);
    Get.lazyPut<OnboardingState>(() => OnboardingState(), fenix: true);
    Get.lazyPut<LoginState>(() => LoginState(), fenix: true);
    Get.lazyPut<ForgotPasswordState>(() => ForgotPasswordState(), fenix: true);
    Get.lazyPut<RestoreAccountState>(() => RestoreAccountState(), fenix: true);
    Get.lazyPut<RegisterState>(() => RegisterState(), fenix: true);
    Get.lazyPut<VerifyState>(() => VerifyState(), fenix: true);
    Get.lazyPut<MainState>(() => MainState(), fenix: true);
    Get.lazyPut<MessagesState>(() => MessagesState(), fenix: true);
    Get.lazyPut<CreateGroupState>(() => CreateGroupState(), fenix: true);
    Get.lazyPut<ChatState>(() => ChatState(), fenix: true);
    Get.lazyPut<GroupSettingsState>(() => GroupSettingsState(), fenix: true);
    Get.lazyPut<FriendsState>(() => FriendsState(), fenix: true);
    Get.lazyPut<AddFriendState>(() => AddFriendState(), fenix: true);
    Get.lazyPut<ProductsState>(() => ProductsState(), fenix: true);
    Get.lazyPut<NumbersState>(() => NumbersState(), fenix: true);
    Get.lazyPut<UserProfileState>(() => UserProfileState(), fenix: true);
    Get.lazyPut<JonliState>(() => JonliState(), fenix: true);
    Get.lazyPut<ProfileState>(() => ProfileState(), fenix: true);
    Get.lazyPut<ProfileEditState>(() => ProfileEditState(), fenix: true);
    Get.lazyPut<SettingsState>(() => SettingsState(), fenix: true);
    Get.lazyPut<SubscriptionState>(() => SubscriptionState(), fenix: true);
    Get.lazyPut<EditBusinessInfoState>(() => EditBusinessInfoState(), fenix: true);
    Get.lazyPut<AddProductState>(() => AddProductState(), fenix: true);
    Get.lazyPut<SupportChatState>(() => SupportChatState(), fenix: true);
  }
}
