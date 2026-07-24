import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/items/conversation_item.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'friend.dart';
import 'friends_action.dart';
import 'friends_state.dart';

class FriendsContent extends ScreenContent<FriendsState> {
  FriendsContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, FriendsState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'nav_friends'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Obx(() {
                  final count = state.pendingCount.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MyIconButton(
                        onClick: () => sendAction(OpenFriendRequests()),
                        icon: Icons.mail_outline_rounded,
                        iconColor: c.textPrimary,
                        iconSize: 22.dp,
                        backgroundColor: c.surface,
                        borderRadius: 12.dp,
                        padding: EdgeInsets.all(10.dp),
                      ),
                      if (count > 0)
                        Positioned(
                          right: -4.dp,
                          top: -4.dp,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.dp, vertical: 1.dp),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(99.dp),
                            ),
                            constraints: BoxConstraints(minWidth: 18.dp, minHeight: 18.dp),
                            alignment: Alignment.center,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: TextStyle(
                                color: c.onAccent,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                SizedBox(width: 8.dp),
                MyIconButton(
                  onClick: () => sendAction(AddFriend()),
                  icon: Icons.person_add_alt_1,
                  iconColor: c.onAccent,
                  iconSize: 20.dp,
                  backgroundColor: c.accent,
                  borderRadius: 12.dp,
                  padding: EdgeInsets.all(10.dp),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: SearchField(
              hint: 'friends_search_hint'.tr,
              onChanged: (v) => sendAction(FriendsSearchChanged(v)),
            ),
          ),
          SizedBox(height: 12.dp),
          Expanded(
            child: Obx(() {
              if (state.loading.value) return const AppLoading();
              final q = state.query.value.trim().toLowerCase();
              bool match(Friend f) => q.isEmpty || f.name.toLowerCase().contains(q);
              final online = state.friends.where((f) => f.online && match(f)).toList();
              final others = state.friends.where((f) => !f.online && match(f)).toList();

              if (online.isEmpty && others.isEmpty) {
                return AppEmptyState(
                  icon: q.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
                  title: q.isEmpty ? 'friends_empty'.tr : 'empty_no_results'.tr,
                  subtitle: q.isEmpty ? 'friends_empty_hint'.tr : null,
                );
              }

              final children = <Widget>[];
              if (online.isNotEmpty) {
                children.add(_sectionHeader(c, '${'friends_online'.tr.toUpperCase()} — ${online.length}'));
                children.addAll(online.map((f) => _item(f, sendAction)));
              }
              if (others.isNotEmpty) {
                children.add(_sectionHeader(c, 'friends_others'.tr.toUpperCase()));
                children.addAll(others.map((f) => _item(f, sendAction)));
              }

              return RefreshIndicator(
                onRefresh: () async => sendAction(RefreshFriends()),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(12.dp, 4.dp, 12.dp, 12.dp),
                  children: children,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppColors c, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(11.dp, 12.dp, 11.dp, 6.dp),
      child: Text(
        label,
        style: TextStyle(
          color: c.textFaint,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _item(Friend f, void Function(MyAction) sendAction) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        sendAction(RemoveFriend(f));
      },
      child: ConversationItem(
        initial: f.initial,
        avatarGradient: f.avatarGradient,
        initialColor: kAvatarFg,
        name: f.name,
        lastMessage: f.status,
        time: '',
        online: f.online,
        unread: 0,
        highlighted: false,
        avatarUrl: f.avatarUrl,
        onTap: () => sendAction(OpenChat(f)),
      ),
    );
  }
}
