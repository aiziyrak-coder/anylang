import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../ui/items/nav_bar_item.dart';
import '../../ui/theme/colors.dart';
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

const int kMainProductsTabIndex = 2;

/// Asosiy ekranning pastki navigatsiya bari — floating liquid glass + markaz product FAB.
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

  int? _badge(int i) {
    if (badgeCounts == null || i >= badgeCounts!.length) return null;
    return badgeCounts![i];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final productsSelected = currentIndex == kMainProductsTabIndex;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 6.dp + bottomInset),
      child: SizedBox(
        height: 72.dp,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Liquid glass capsule
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _LiquidGlassCapsule(
                child: SizedBox(
                  height: 62.dp,
                  child: Row(
                    children: [
                      for (int i = 0; i < kMainNavTabs.length; i++)
                        if (i == kMainProductsTabIndex)
                          const Expanded(child: SizedBox.shrink())
                        else
                          Expanded(
                            child: NavBarItem(
                              iconAsset: kMainNavTabs[i].iconAsset,
                              label: kMainNavTabs[i].labelKey.tr,
                              selected: currentIndex == i,
                              badgeCount: _badge(i),
                              onTap: () => onTap(i),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            // Center product FAB — raised above the glass
            Positioned(
              bottom: 14.dp,
              child: _ProductsFab(
                selected: productsSelected,
                label: kMainNavTabs[kMainProductsTabIndex].labelKey.tr,
                onTap: () => onTap(kMainProductsTabIndex),
                colors: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassCapsule extends StatelessWidget {
  final Widget child;

  const _LiquidGlassCapsule({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(28.dp);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: c.isDark
                ? const Color(0x99000000)
                : const Color(0x28071526),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: c.accent.withValues(alpha: c.isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: c.isDark
                    ? const [
                        Color(0xCC243B55),
                        Color(0xB8152A42),
                        Color(0xD0122438),
                      ]
                    : const [
                        Color(0xF2FFFFFF),
                        Color(0xE8F3F7FC),
                        Color(0xF0FFFFFF),
                      ],
              ),
              border: Border.all(
                color: c.isDark
                    ? const Color(0x40FFFFFF)
                    : const Color(0x99FFFFFF),
                width: 1.1,
              ),
            ),
            child: Stack(
              children: [
                // Top liquid highlight
                Positioned(
                  left: 12.dp,
                  right: 12.dp,
                  top: 0,
                  height: 1.2.dp,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.dp),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          c.isDark
                              ? const Color(0x55FFFFFF)
                              : const Color(0xAAFFFFFF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsFab extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final AppColors colors;

  const _ProductsFab({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final size = selected ? 64.dp : 58.dp;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.accentButtonGradient,
              border: Border.all(
                color: c.isDark
                    ? const Color(0x66FFFFFF)
                    : const Color(0xCCFFFFFF),
                width: 2.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: selected ? 0.6 : 0.4),
                  blurRadius: selected ? 24 : 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: c.isDark
                      ? const Color(0x66000000)
                      : const Color(0x22071526),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              kMainNavTabs[kMainProductsTabIndex].iconAsset,
              width: selected ? 30.dp : 27.dp,
              height: selected ? 30.dp : 27.dp,
              colorFilter: ColorFilter.mode(c.onAccent, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
