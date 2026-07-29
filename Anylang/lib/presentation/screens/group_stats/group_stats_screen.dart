import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/public_profile_cache.dart';
import '../../../data/network/chat_repository.dart';
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

  bool _openingProfile = false;

  @override
  void initState(GroupStatsPayload? payload) {
    if (payload == null) {
      Future.microtask(() {
        showAppError('screen_payload_missing'.tr);
        popBackNavigate();
      });
      return;
    }
    state.chatId.value = payload.chatId;
    state.title.value = payload.title;
    _load();
  }

  Future<void> _load() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) {
      showAppError('group_stats_invalid_chat'.tr);
      popBackNavigate();
      return;
    }
    state.loading.value = true;
    try {
      final result = await Get.find<ChatRepository>().groupStats(chatId);
      result.when(
        success: (data) {
          final map = asMap(data);
          if (map == null) {
            showAppError('unknown_error'.tr);
            return;
          }
          state.data.value = GroupStatsData.fromApi(map);
          final t = map['group_title']?.toString().trim();
          if (t != null && t.isNotEmpty) {
            state.title.value = t;
          }
        },
        failure: showAppError,
      );
    } finally {
      state.loading.value = false;
    }
  }

  /// Tez ochish: local cache → stats preview; to‘liq yangilash UserProfileScreen ichida.
  Future<void> _openUser(int userId) async {
    if (userId <= 0) return;
    // Navigatsiya yoki oldingi ochish jarayonida — ikkinchi tap stack'ga qo'shilmasin.
    if (_openingProfile || isNavigating) return;
    _openingProfile = true;
    try {
      final cached = PublicProfileCache.get(userId);
      final UserProfilePayload payload;
      if (cached != null) {
        payload = UserProfilePayload.fromApi(cached);
      } else {
        payload = _previewFromStats(userId) ??
            UserProfilePayload.preview(id: userId, name: 'User');
      }
      await navigate(UserProfileScreen(), payload: payload);
    } finally {
      _openingProfile = false;
    }
  }

  UserProfilePayload? _previewFromStats(int userId) {
    final data = state.data.value;
    if (data == null) return null;

    String? name;
    String? logo;
    if (data.topCompany?.userId == userId) {
      name = data.topCompany!.companyName;
      logo = data.topCompany!.logoUrl;
    } else if (data.topProducts?.userId == userId) {
      name = data.topProducts!.companyName;
      logo = data.topProducts!.logoUrl;
    } else if (data.topDeals?.userId == userId) {
      name = data.topDeals!.companyName;
      logo = data.topDeals!.logoUrl;
    } else {
      for (final c in data.companies) {
        if (c.userId == userId) {
          name = c.companyName;
          logo = c.logoUrl;
          break;
        }
      }
    }
    if (name == null || name.trim().isEmpty) return null;
    return UserProfilePayload.preview(
      id: userId,
      name: name,
      avatarUrl: logo,
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
