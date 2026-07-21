import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/friend_result_item.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'add_friend_action.dart';
import 'add_friend_result.dart';
import 'add_friend_state.dart';

class AddFriendContent extends ScreenContent<AddFriendState> {

  @override
  Widget build(BuildContext context, AddFriendState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 4.dp),
              AppTopBar(
                title: 'add_friend_title'.tr,
                onBack: () => sendAction(Back()),
              ),
              SizedBox(height: 14.dp),
              SearchField(
                hint: 'add_friend_search_hint'.tr,
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
                  final q = state.query.value.trim().toLowerCase();
                  final items = q.isEmpty
                      ? state.results.toList()
                      : state.results
                          .where((r) =>
                              r.name.toLowerCase().contains(q) ||
                              r.subtitle.toLowerCase().contains(q))
                          .toList();
                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: 12.dp),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _item(items[i], sendAction),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(AddFriendResult r, void Function(MyAction) sendAction) {
    final bool isFriend = r.action == FriendActionState.message;
    final String subtitle = isFriend ? 'add_friend_is_friend'.tr : r.subtitle;
    final String label = switch (r.action) {
      FriendActionState.add => 'add_friend_add'.tr,
      FriendActionState.message => 'add_friend_message'.tr,
      FriendActionState.requested => 'add_friend_requested'.tr,
    };

    return FriendResultItem(
      initial: r.initial,
      avatarGradient: r.avatarGradient,
      name: r.name,
      subtitle: subtitle,
      online: r.online,
      action: r.action,
      actionLabel: label,
      onAction: () => sendAction(
        isFriend ? MessageResult(r) : SendFriendRequest(r),
      ),
    );
  }
}
