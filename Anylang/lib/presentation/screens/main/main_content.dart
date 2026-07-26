import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/connection_status_banner.dart';
import '../../ui/gradient_background.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../friends/friends_screen.dart';
import '../friends/friends_state.dart';
import '../jonli/jonli_screen.dart';
import '../messages/messages_screen.dart';
import '../messages/messages_state.dart';
import '../products/products_screen.dart';
import '../profile/profile_screen.dart';
import 'main_action.dart';
import 'main_bottom_nav.dart';
import 'main_state.dart';

class MainContent extends ScreenContent<MainState> {
  /// Lazy tab bodies: faqat ochilgan tablar quriladi (API storm oldini olish).
  final List<Widget?> _tabBodies = List<Widget?>.filled(5, null);

  Widget _buildTab(int index) {
    return switch (index) {
      0 => MessagesScreen().build(),
      1 => FriendsScreen().build(),
      2 => ProductsScreen().build(),
      3 => JonliScreen().build(),
      4 => ProfileScreen().build(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _ensureTab(int index) {
    final existing = _tabBodies[index];
    if (existing != null) return existing;
    final built = _buildTab(index);
    _tabBodies[index] = built;
    return built;
  }

  @override
  void initContent() {
    // Default tab — xabarlar.
    _ensureTab(0);
  }

  @override
  Widget build(BuildContext context, MainState state, FutureOr<void> Function(MyAction action) sendAction) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        sendAction(HandleSystemBack());
      },
      child: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ConnectionStatusBanner(),
              Expanded(
                child: Obx(() {
                  final idx = state.currentTab.value;
                  _ensureTab(idx);
                  return IndexedStack(
                    index: idx,
                    children: List<Widget>.generate(
                      5,
                      (i) => _tabBodies[i] ?? const SizedBox.shrink(),
                    ),
                  );
                }),
              ),
              // Pastki navigatsiya bari.
              Obx(() {
                final messagesBadge = Get.isRegistered<MessagesState>()
                    ? Get.find<MessagesState>()
                        .conversations
                        .fold<int>(0, (sum, c) => sum + c.unread)
                    : 0;
                final friendsBadge = Get.isRegistered<FriendsState>()
                    ? Get.find<FriendsState>().pendingCount.value
                    : 0;
                return MainBottomNav(
                  currentIndex: state.currentTab.value,
                  badgeCounts: [messagesBadge, friendsBadge, 0, 0, 0],
                  onTap: (i) => sendAction(TabSelected(i)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
