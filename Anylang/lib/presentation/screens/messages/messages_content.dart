import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/forward_pending_store.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/items/conversation_item.dart';
import '../../ui/items/friend_result_item.dart';
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
                  child: Obx(() {
                    if (state.selecting.value) {
                      return Text(
                        '${state.selectedIds.length}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 27.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }
                    return Text(
                      'nav_messages'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 27.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }),
                ),
                Obx(() {
                  if (!state.selecting.value) {
                    return Builder(
                      builder: (btnCtx) {
                        return MyIconButton(
                          onClick: () {
                            final box =
                                btnCtx.findRenderObject() as RenderBox?;
                            if (box == null || !box.hasSize) {
                              sendAction(
                                NewConversation(
                                  Rect.fromLTWH(
                                    MediaQuery.sizeOf(btnCtx).width - 70,
                                    48,
                                    44,
                                    44,
                                  ),
                                ),
                              );
                              return;
                            }
                            final offset = box.localToGlobal(Offset.zero);
                            sendAction(
                              NewConversation(
                                Rect.fromLTWH(
                                  offset.dx,
                                  offset.dy,
                                  box.size.width,
                                  box.size.height,
                                ),
                              ),
                            );
                          },
                          icon: Icons.add,
                          iconColor: c.accent,
                          iconSize: 20.dp,
                          backgroundColor: c.logoTileBg,
                          borderRadius: 12.dp,
                          padding: EdgeInsets.all(10.dp),
                        );
                      },
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyIconButton(
                        onClick: () => sendAction(BulkMuteSelected()),
                        icon: Icons.notifications_off_outlined,
                        iconColor: c.accentText,
                        iconSize: 20.dp,
                        backgroundColor: c.logoTileBg,
                        borderRadius: 12.dp,
                        padding: EdgeInsets.all(10.dp),
                      ),
                      SizedBox(width: 6.dp),
                      MyIconButton(
                        onClick: () => sendAction(BulkHideSelected()),
                        icon: Icons.visibility_off_outlined,
                        iconColor: c.accentText,
                        iconSize: 20.dp,
                        backgroundColor: c.logoTileBg,
                        borderRadius: 12.dp,
                        padding: EdgeInsets.all(10.dp),
                      ),
                      SizedBox(width: 6.dp),
                      MyIconButton(
                        onClick: () => sendAction(ExitListSelect()),
                        icon: Icons.close,
                        iconColor: c.accentText,
                        iconSize: 20.dp,
                        backgroundColor: c.logoTileBg,
                        borderRadius: 12.dp,
                        padding: EdgeInsets.all(10.dp),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          Obx(() {
            if (!Get.isRegistered<ForwardPendingStore>()) {
              return const SizedBox.shrink();
            }
            final store = Get.find<ForwardPendingStore>();
            if (!store.hasPending) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
              child: Material(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.dp),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
                  child: Row(
                    children: [
                      Icon(Icons.shortcut_rounded, color: c.accentText, size: 20.dp),
                      SizedBox(width: 10.dp),
                      Expanded(
                        child: Text(
                          'chat_forward_pick'.tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      MyIconButton(
                        onClick: store.clear,
                        icon: Icons.close_rounded,
                        iconColor: c.textSecondary,
                        iconSize: 18.dp,
                        backgroundColor: Colors.transparent,
                        borderRadius: 10.dp,
                        padding: EdgeInsets.all(4.dp),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: 16.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: SearchField(
              hint: 'messages_search_hint'.tr,
              onChanged: (v) => sendAction(SearchChanged(v)),
            ),
          ),
          SizedBox(height: 12.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: Obx(() {
              final selected = state.listFilter.value;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(
                      c,
                      label: 'messages_filter_all'.tr,
                      selected: selected == MessagesListFilter.all,
                      onTap: () => sendAction(
                        ChangeMessagesFilter(MessagesListFilter.all),
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    _chip(
                      c,
                      label: 'messages_filter_unread'.tr,
                      selected: selected == MessagesListFilter.unread,
                      onTap: () => sendAction(
                        ChangeMessagesFilter(MessagesListFilter.unread),
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    _chip(
                      c,
                      label: 'messages_filter_chats'.tr,
                      selected: selected == MessagesListFilter.chats,
                      onTap: () => sendAction(
                        ChangeMessagesFilter(MessagesListFilter.chats),
                      ),
                    ),
                    SizedBox(width: 8.dp),
                    _chip(
                      c,
                      label: 'messages_filter_groups'.tr,
                      selected: selected == MessagesListFilter.groups,
                      onTap: () => sendAction(
                        ChangeMessagesFilter(MessagesListFilter.groups),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: 8.dp),
          Expanded(
            child: Obx(() {
              if (state.loading.value) return const AppLoading();
              final q = state.query.value.trim();
              final searching = q.isNotEmpty;
              if (searching && state.searching.value) {
                return const AppLoading();
              }
              if (searching) {
                return _searchResults(c, state, sendAction);
              }
              final items = state.conversations.toList();
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'messages_empty'.tr,
                  subtitle: 'messages_empty_hint'.tr,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => sendAction(RefreshConversations()),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                      muted: conv.muted || SessionStore.isChatMuted(conv.id),
                      pinned: conv.pinned,
                      isGroup: conv.isGroup,
                      avatarUrl: conv.avatarUrl,
                      selected: state.selecting.value &&
                          state.selectedIds.contains(conv.id),
                      onTap: () {
                        if (state.selecting.value) {
                          sendAction(ToggleListSelect(conv));
                        } else {
                          sendAction(OpenConversation(conv));
                        }
                      },
                      onLongPress: (rect) {
                        if (state.selecting.value) {
                          sendAction(ToggleListSelect(conv));
                        } else {
                          sendAction(LongPressConversation(conv, rect));
                        }
                      },
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

  Widget _searchResults(
    AppColors c,
    MessagesState state,
    void Function(MyAction action) sendAction,
  ) {
    final users = state.userResults.toList();
    final chats = state.searchResults.toList();
    if (users.isEmpty && chats.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'empty_no_results'.tr,
        subtitle: 'messages_search_empty_hint'.tr,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => sendAction(RefreshConversations()),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.dp, 4.dp, 12.dp, 12.dp),
        children: [
          if (users.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(8.dp, 4.dp, 8.dp, 8.dp),
              child: Text(
                'messages_people'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final user in users)
              Material(
                color: Colors.transparent,
                child: FriendResultItem(
                  initial: user.initial,
                  avatarGradient: user.avatarGradient,
                  avatarUrl: user.avatarUrl,
                  name: user.name,
                  subtitle: user.subtitle,
                  online: user.online,
                  action: FriendActionState.message,
                  actionLabel: 'add_friend_message'.tr,
                  onAction: () => sendAction(OpenUserChat(user)),
                ),
              ),
            if (chats.isNotEmpty) SizedBox(height: 8.dp),
          ],
          if (chats.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(8.dp, 4.dp, 8.dp, 8.dp),
              child: Text(
                'messages_chats'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final conv in chats)
              ConversationItem(
                initial: conv.initial,
                avatarGradient: conv.avatarGradient,
                initialColor: conv.initialColor,
                name: conv.name,
                lastMessage: conv.lastMessage,
                time: conv.time,
                online: conv.online,
                unread: conv.unread,
                highlighted: conv.highlighted,
                muted: conv.muted || SessionStore.isChatMuted(conv.id),
                pinned: conv.pinned,
                isGroup: conv.isGroup,
                avatarUrl: conv.avatarUrl,
                onTap: () => sendAction(OpenConversation(conv)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    AppColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? c.accentSoft : c.surface,
      borderRadius: BorderRadius.circular(99.dp),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.accentText : c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
