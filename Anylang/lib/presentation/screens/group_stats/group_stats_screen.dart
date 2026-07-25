import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'group_stats_action.dart';
import 'group_stats_content.dart';
import 'group_stats_models.dart';
import 'group_stats_payload.dart';
import 'group_stats_state.dart';

class GroupStatsScreen extends Screen<GroupStatsState, GroupStatsPayload> {
  GroupStatsScreen() : super(mobileContent: GroupStatsContent());

  @override
  void initState(GroupStatsPayload? payload) {
    if (payload != null) {
      state.chatId.value = payload.chatId;
      state.title.value = payload.title;
    }
    _load();
  }

  Future<void> _load() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) {
      state.loading.value = false;
      return;
    }
    state.loading.value = true;
    final result = await Get.find<ChatRepository>().groupStats(chatId);
    state.loading.value = false;
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.data.value = GroupStatsData.fromApi(map);
      },
      failure: showAppError,
    );
  }

  Future<void> _openUser(int userId) async {
    if (userId <= 0) return;
    final profile = await Get.find<ProfileRepository>().getPublicUser(userId);
    final map = asMap(profile.dataOrNull);
    if (map == null) {
      showAppError(profile.errorOrNull ?? 'error'.tr);
      return;
    }
    await navigate(
      UserProfileScreen(),
      payload: UserProfilePayload.fromApi(map),
    );
  }

  @override
  Future<void> actionHandler(GroupStatsState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case GroupStatsRefresh _:
        await _load();
      case GroupStatsOpenUser a:
        await _openUser(a.userId);
    }
  }
}
