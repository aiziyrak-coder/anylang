import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/gradient_background.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../friends/friends_screen.dart';
import '../jonli/jonli_screen.dart';
import '../messages/messages_screen.dart';
import '../products/products_screen.dart';
import '../profile/profile_screen.dart';
import 'main_action.dart';
import 'main_bottom_nav.dart';
import 'main_state.dart';

class MainContent extends ScreenContent<MainState> {

  // Tab body'lari bir marta quriladi va IndexedStack'da tirik saqlanadi
  // (tab almashganda qayta qurilmaydi, holat yo'qolmaydi).
  late final List<Widget> _tabBodies;

  @override
  void initContent() {
    _tabBodies = [
      MessagesScreen().build(),        // 0 — Xabarlar
      FriendsScreen().build(),         // 1 — Do'stlar
      ProductsScreen().build(),        // 2 — Mahsulotlar
      JonliScreen().build(),           // 3 — Jonli
      ProfileScreen().build(),         // 4 — Profil
    ];
  }

  @override
  Widget build(BuildContext context, MainState state, void Function(MyAction action) sendAction) {
    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Obx(() => IndexedStack(
                    index: state.currentTab.value,
                    children: _tabBodies,
                  )),
            ),
            // Pastki navigatsiya bari.
            Obx(() => MainBottomNav(
                  currentIndex: state.currentTab.value,
                  onTap: (i) => sendAction(TabSelected(i)),
                )),
          ],
        ),
      ),
    );
  }
}
