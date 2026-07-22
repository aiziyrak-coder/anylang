import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/friend_result_item.dart';
import '../../ui/items/user_search_item.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'add_friend_action.dart';
import 'add_friend_payload.dart';
import 'add_friend_result.dart';
import 'add_friend_state.dart';

class AddFriendContent extends ScreenContent<AddFriendState> {
  @override
  Widget build(BuildContext context, AddFriendState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final isFriendsMode = state.mode == AddFriendMode.friends;

    return GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 4.dp),
              AppTopBar(
                title: (isFriendsMode ? 'friends_add_title' : 'add_friend_title').tr,
                onBack: () => sendAction(Back()),
              ),
              SizedBox(height: 14.dp),
              SearchField(
                hint: 'add_friend_search_hint'.tr,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (v) => sendAction(AddFriendSearchChanged(v)),
              ),
              SizedBox(height: 18.dp),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.dp),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'add_friend_results'.tr.toUpperCase(),
                    style: TextStyle(
                      color: c.textFaint,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4.dp),
              Expanded(
                child: Obx(() {
                  final q = state.query.value.trim();
                  final isSearching = q.length >= 3;

                  if (isSearching) {
                    if (state.searching.value) return const AppLoading();
                    final items = state.results.toList();
                    if (items.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'add_friend_no_results'.tr,
                      );
                    }
                    return _buildList(items, isFriendsMode, sendAction);
                  }

                  // Input bo'sh / qisqa: do'stlar rejimida yuborilgan so'rovlar
                  if (isFriendsMode) {
                    if (state.loadingSent.value) return const AppLoading();
                    final sent = state.sentRequests.toList();
                    if (sent.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.tag_rounded,
                        title: 'add_friend_empty'.tr,
                      );
                    }
                    return _buildList(sent, true, sendAction);
                  }

                  return AppEmptyState(
                    icon: Icons.tag_rounded,
                    title: 'add_friend_empty'.tr,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<AddFriendResult> items,
    bool isFriendsMode,
    void Function(MyAction) sendAction,
  ) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 12.dp),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r = items[i];
        if (isFriendsMode) {
          return KeyedSubtree(
            key: ValueKey('friend-${r.id}-${r.action.name}-${r.requestId}'),
            child: _friendItem(r, sendAction),
          );
        }
        return UserSearchItem(
          initial: r.initial,
          avatarGradient: r.avatarGradient,
          name: r.name,
          subtitle: r.subtitle,
          online: r.online,
          onTap: () => sendAction(OpenUserChat(r)),
        );
      },
    );
  }

  Widget _friendItem(AddFriendResult r, void Function(MyAction) sendAction) {
    final isFriend = r.action == FriendActionState.message;
    final isRequested = r.action == FriendActionState.requested;
    final label = isFriend
        ? 'add_friend_message'.tr
        : (isRequested
            ? 'add_friend_requested'.tr
            : 'add_friend_add'.tr);

    return FriendResultItem(
      initial: r.initial,
      avatarGradient: r.avatarGradient,
      name: r.name,
      subtitle: r.subtitle,
      online: r.online,
      action: r.action,
      actionLabel: label,
      onAction: () {
        if (isFriend) {
          sendAction(MessageResult(r));
        } else if (isRequested) {
          // Status: "So'rov yuborildi" — bekor qilish uchun qayta bosish.
          sendAction(CancelFriendRequest(r));
        } else {
          sendAction(SendFriendRequest(r));
        }
      },
    );
  }
}
