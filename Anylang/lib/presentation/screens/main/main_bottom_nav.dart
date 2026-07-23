import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/glass_surface.dart';
import '../../ui/items/nav_bar_item.dart';
import '../../utils/size_controller.dart';

/// Asosiy ekran pastki navigatsiyasining bitta tab ta'rifi (ikon + yorliq kaliti).
class MainNavTab {
  final String iconAsset;
  final String labelKey;
  const MainNavTab(this.iconAsset, this.labelKey);
}

/// Pastki navigatsiya tablari — tartibi UI'da ham, body'da ham shu ro'yxatdan olinadi.
const List<MainNavTab> kMainNavTabs = [
  MainNavTab('assets/icons/ic_chat.svg', 'nav_messages'),
  MainNavTab('assets/icons/ic_friends.svg', 'nav_friends'),
  MainNavTab('assets/icons/ic_products.svg', 'nav_products'),
  MainNavTab('assets/icons/ic_live.svg', 'nav_live'),
  MainNavTab('assets/icons/ic_profile.svg', 'nav_profile'),
];

/// Asosiy ekranning pastki navigatsiya bari (5 ta tab) — frosted glass.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int>? badgeCounts;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBar(
      topEdge: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 8.dp, bottom: 4.dp),
          child: Row(
            children: [
              for (int i = 0; i < kMainNavTabs.length; i++)
                Expanded(
                  child: NavBarItem(
                    iconAsset: kMainNavTabs[i].iconAsset,
                    label: kMainNavTabs[i].labelKey.tr,
                    selected: currentIndex == i,
                    badgeCount: badgeCounts != null && i < badgeCounts!.length
                        ? badgeCounts![i]
                        : null,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
