import 'package:flutter/material.dart';
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
import 'messages_action.dart';
import 'messages_state.dart';

class MessagesContent extends ScreenContent<MessagesState> {
  MessagesContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, MessagesState state, void Function(MyAction action) sendAction) {
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
                    'nav_messages'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                MyIconButton(
                  onClick: () => sendAction(NewConversation()),
                  icon: Icons.add,
                  iconColor: c.accent,
                  iconSize: 20.dp,
                  backgroundColor: c.logoTileBg,
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
              hint: 'messages_search_hint'.tr,
              onChanged: (v) => sendAction(SearchChanged(v)),
            ),
          ),
          SizedBox(height: 12.dp),
          Expanded(
            child: Obx(() {
              if (state.loading.value) return const AppLoading();
              final q = state.query.value.trim();
              final searching = q.isNotEmpty;
              if (searching && state.searching.value) {
                return const AppLoading();
              }
              final items = searching
                  ? state.searchResults.toList()
                  : state.conversations.toList();
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: searching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
                  title: searching ? 'empty_no_results'.tr : 'messages_empty'.tr,
                  subtitle: searching ? null : 'messages_empty_hint'.tr,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => sendAction(RefreshConversations()),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(12.dp, 4.dp, 12.dp, 12.dp),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final conv = items[i];
                    return ConversationItem(
                      initial: conv.initial,
                      avatarGradient: conv.avatarGradient,
                      initialColor: conv.initialColor,
                      name: conv.name,
                      lastMessage: conv.lastMessage,
                      time: conv.time,
                      online: conv.online,
                      unread: conv.unread,
                      highlighted: conv.highlighted,
                      onTap: () => sendAction(OpenConversation(conv)),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
