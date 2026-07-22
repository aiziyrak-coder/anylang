import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../products/product_info_bottom_sheet.dart';
import 'user_profile_action.dart';
import 'user_profile_content.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileScreen extends Screen<UserProfileState, UserProfilePayload> {
  UserProfileScreen() : super(mobileContent: UserProfileContent());

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
        final data = state.data;
        if (data == null || data.id <= 0) return;
        final result = await Get.find<ChatRepository>().createChat(data.id);
        result.when(
          success: (raw) {
            final map = asMap(raw);
            final chatId = (map?['id'] as num?)?.toInt() ?? 0;
            navigate(
              ChatScreen(),
              payload: ChatPayload(
                chatId: chatId,
                peerId: data.id,
                name: data.name,
                initial: data.initial,
                avatarGradient: data.avatarGradient,
              ),
            );
          },
          failure: showAppError,
        );
      case CallUser _:
        break;
      case OpenWebsite _:
        final url = state.data?.website;
        if (url == null || url.isEmpty) return;
        final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      case OpenListing a:
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () {},
        );
    }
  }
}
