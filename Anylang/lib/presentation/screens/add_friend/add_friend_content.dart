import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/friend_result_item.dart';
import '../../ui/items/user_card_item.dart';
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
  Widget build(BuildContext context, AddFriendState state, FutureOr<void> Function(MyAction action) sendAction) {
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
                    final err = state.searchError.value;
                    if (err != null && err.isNotEmpty) {
                      return AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'add_friend_search_failed'.tr,
                        subtitle: err,
                      );
                    }
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
                    final sentErr = state.sentLoadError.value;
                    if (sentErr != null && sentErr.isNotEmpty) {
                      return AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'add_friend_sent_load_failed'.tr,
                        subtitle: sentErr,
                      );
                    }
                    final sent = state.sentRequests.toList();
                    if (sent.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.tag_rounded,
                        title: 'add_friend_empty'.tr,
                      );
                    }
                    return _buildList(sent, true, sendAction);
                  }

                  final qHint = state.searchError.value;
                  if (q.length >= 1 &&
                      q.length < 3 &&
                      qHint != null &&
                      qHint.isNotEmpty) {
                    return AppEmptyState(
                      icon: Icons.tag_rounded,
                      title: qHint,
                    );
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
        return KeyedSubtree(
          key: ValueKey('friend-${r.id}-${r.action.name}-${r.requestId}'),
          child: _userCard(r, isFriendsMode, sendAction),
        );
      },
    );
  }

  Widget _userCard(
    AddFriendResult r,
    bool isFriendsMode,
    void Function(MyAction) sendAction,
  ) {
    final isFriend = r.action == FriendActionState.message;
    final isRequested = r.action == FriendActionState.requested;
    void openChat() {
      if (isFriendsMode) {
        sendAction(MessageResult(r));
      } else {
        sendAction(OpenUserChat(r));
      }
    }

    return UserCardItem(
      initial: r.initial,
      avatarGradient: r.avatarGradient,
      avatarUrl: r.avatarUrl,
      name: r.name,
      online: r.online,
      country: r.country,
      businessRole: r.businessRole,
      keywords: r.keywords,
      isBusiness: r.isBusiness,
      rating: r.rating,
      verified: r.verified,
      languages: r.languages,
      productsCount: r.productsCount,
      countriesCount: r.countriesCount,
      showMessage: true,
      showAdd: !isFriend,
      addEnabled: !isRequested,
      addLabel: isRequested
          ? 'add_friend_requested'.tr
          : 'user_card_add'.tr,
      onTap: openChat,
      onMessage: openChat,
      onAdd: () {
        if (isRequested) {
          sendAction(CancelFriendRequest(r));
        } else {
          sendAction(SendFriendRequest(r));
        }
      },
    );
  }
}
