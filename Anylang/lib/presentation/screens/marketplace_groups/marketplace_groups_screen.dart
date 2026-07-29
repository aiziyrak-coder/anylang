import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/marketplace_groups_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../marketplace_verified_group/marketplace_verified_group_payload.dart';
import '../marketplace_verified_group/marketplace_verified_group_screen.dart';
import 'marketplace_group.dart';
import 'marketplace_groups_action.dart';
import 'marketplace_groups_content.dart';
import 'marketplace_groups_state.dart';

class MarketplaceGroupsScreen extends Screen<MarketplaceGroupsState, void> {
  MarketplaceGroupsScreen() : super(mobileContent: MarketplaceGroupsContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load({bool fromRefresh = false}) async {
    state.loading.value = true;
    try {
      final result = await Get.find<MarketplaceGroupsRepository>().list();
      result.when(
        success: (data) {
          state.loadError.value = null;
          final map = asMap(data);
          final raw = map?['items'];
          final items = <MarketplaceGroup>[];
          if (raw is List) {
            for (final e in raw) {
              if (e is Map) {
                items.add(MarketplaceGroup.fromApi(Map<String, dynamic>.from(e)));
              }
            }
          }
          state.viewerVerified.value = map?['viewer_verified'] == true;
          state.groups.assignAll(items);
        },
        failure: (err) {
          final msg = AuthValidators.safeError(
            err,
            fallbackKey: 'marketplace_groups_load_failed',
          );
          if (fromRefresh && state.groups.isNotEmpty) {
            showAppError(msg);
          } else {
            state.loadError.value = msg;
          }
        },
      );
    } finally {
      state.loading.value = false;
    }
  }

  Future<void> _openGroup(MarketplaceGroup group) async {
    if (state.joining.value) return;
    // Verified + qo‘shilmagan: tarif o‘rniga guruh info + ishonchlilik ekrani.
    if (group.verifiedOnly && !group.joined && !group.canJoin) {
      await navigate(
        MarketplaceVerifiedGroupScreen(),
        payload: MarketplaceVerifiedGroupPayload(group: group),
      );
      await _load(fromRefresh: true);
      return;
    }
    state.joining.value = true;
    try {
      final result = await Get.find<MarketplaceGroupsRepository>().join(group.slug);
      final map = asMap(result.dataOrNull);
      if (map == null) {
        showAppError(result.errorOrNull ?? 'error'.tr);
        return;
      }
      final chatId = (map['chat_id'] as num?)?.toInt() ??
          (map['id'] as num?)?.toInt() ??
          0;
      if (chatId <= 0) {
        showAppError('marketplace_join_no_chat'.tr);
        return;
      }
      final title = (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : group.title;
      final emoji = map['marketplace_emoji']?.toString() ?? group.emoji;
      final idx = state.groups.indexWhere((g) => g.slug == group.slug);
      if (idx >= 0) {
        final g = state.groups[idx];
        state.groups[idx] = g.copyWith(
          memberCount: g.joined ? g.memberCount : g.memberCount + 1,
          joined: true,
          canJoin: true,
          myRole: map['my_role']?.toString() ?? g.myRole,
        );
      }
      await navigate(
        ChatScreen(),
        payload: ChatPayload(
          chatId: chatId,
          peerId: 0,
          name: '$emoji $title',
          initial: initialsOf(title),
          avatarGradient: avatarGradientFor(chatId),
          isGroup: true,
          myRole: map['my_role']?.toString(),
          isSuper: map['is_super'] == true,
          inviteLink: map['invite_link']?.toString(),
          isMarketplace: true,
          marketplaceSlug: group.slug,
        ),
      );
    } finally {
      state.joining.value = false;
    }
  }

  @override
  Future<void> actionHandler(
    MarketplaceGroupsState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case MarketplaceGroupsRefresh _:
        await _load(fromRefresh: true);
      case MarketplaceGroupOpen a:
        await _openGroup(a.group);
    }
  }
}
